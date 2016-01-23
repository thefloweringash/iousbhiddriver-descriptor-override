def num_packing(len)
  case len
  when 1; "C"
  when 2; "S<"
  when 4; "L<"
  end
end
def unpack_num(bytes)
  if packing = num_packing(bytes.length)
    bytes.unpack(packing).first
  else
    raise "Unable to unpack: #{bytes.inspect}"
  end
end
def pack_num(len, num)
  if packing = num_packing(len)
    [num].pack(packing)
  else
    raise "Unable to pack number #{num} with length #{len}"
  end
end

class Tag
  attr_reader :byte, :name
  def initialize(byte, name)
    @byte = byte; @name = name
  end

  def type
    (@byte & 12) >> 2
  end

  def is_main?  ; type == 0; end
  def is_global?; type == 1; end
  def is_local? ; type == 2; end
end

module HIDTags
  HID_TAGS = [
              # main items
              [0x80, 'INPUT'           ],
              [0x90, 'OUTPUT'          ],
              [0xB0, 'FEATURE'         ],
              [0xA0, 'COLLECTION'      ],
              [0xC0, 'END_COLLECTION'  ],

              # global items
              [0x00 | 0x4, 'USAGE_PAGE'      ],
              [0x10 | 0x4, 'LOGICAL_MINIMUM' ],
              [0x20 | 0x4, 'LOGICAL_MAXIMUM' ],
              [0x30 | 0x4, 'PHYSICAL_MINIMUM'],
              [0x40 | 0x4, 'PHYSICAL_MAXIMUM'],
              [0x50 | 0x4, 'UNIT_EXPONENT'   ],
              [0x60 | 0x4, 'UNIT'            ],
              [0x70 | 0x4, 'REPORT_SIZE'     ],
              [0x80 | 0x4, 'REPORT_ID'       ],
              [0x90 | 0x4, 'REPORT_COUNT'    ],
              [0xA0 | 0x4, 'PUSH'            ],
              [0xB0 | 0x4, 'POP'             ],

              # local items (incomplete)
              [0x00 | 0x8, 'USAGE'           ],
              [0x10 | 0x8, 'USAGE_MINIMUM'   ],
              [0x20 | 0x8, 'USAGE_MAXIMUM'   ],
             ]

  @@hid_tag_by_byte = Hash.new
  @@hid_tag_by_name = Hash.new

  HID_TAGS.each do |byte, name|
    tag = Tag.new(byte, name)
    @@hid_tag_by_name[name] = tag
    @@hid_tag_by_byte[byte] = tag
  end

  USAGE = @@hid_tag_by_name['USAGE']
  USAGE_PAGE = @@hid_tag_by_name['USAGE_PAGE']
  USAGE_MINIMUM = @@hid_tag_by_name['USAGE_MINIMUM']
  USAGE_MAXIMUM = @@hid_tag_by_name['USAGE_MAXIMUM']
  REPORT_COUNT = @@hid_tag_by_name['REPORT_COUNT']

  def self.tag_by_name(name)
    @@hid_tag_by_name[name]
  end

  def self.tag_by_byte(name)
    @@hid_tag_by_byte[name]
  end
end

class UsageRange
  attr_reader :min_item, :max_item

  def initialize(min_item, max_item)
    @min_item = min_item
    @max_item = max_item
  end

  def without_pos
    min_item = @min_item.dup
    min_item.delete(:pos)

    max_item = @max_item.dup
    max_item.delete(:pos)

    UsageRange.new(min_item, max_item)
  end

  def min
    unpack_num(min_item[:data])
  end

  def max
    unpack_num(max_item[:data])
  end

  def includes_usage?(usage)
    (self.min..self.max).include? usage
  end

  def count
    (self.max - self.min) + 1
  end

  def tags
    [[HIDTags::USAGE_MINIMUM, min_item],
     [HIDTags::USAGE_MAXIMUM, max_item]]
  end

  def values
    (self.min..self.max).to_a
  end
end

class UsageImmediate
  attr_reader :item

  def initialize(item)
    @item = item
  end

  def without_pos
    item = @item.dup
    item.delete(:pos)
    UsageImmediate.new(item)
  end

  def includes_usage?(usage)
    usage == unpack_num(@item[:data])
  end

  def count
    1
  end

  def tags
    [[HIDTags::USAGE, item]]
  end

  def values
    [unpack_num(item[:data])]
  end
end

class UsageImmediates
  attr_reader :items

  def initialize(items)
    @items = items
  end

  def without_pos
    UsageImmediates.new(
      @items.map {|x| x = x.dup; x.delete(:pos); x})
  end

  def includes_usage?(usage)
    self.items.any? { |item| unpack_num(item[:data]) == usage }
  end

  def count
    self.items.count
  end

  def tags
    self.items.map do |item|
      [HIDTags::USAGE, item]
    end
  end

  def values
    self.items.map do |item|
      unpack_num(item[:data])
    end
  end

end

class MainItem
  attr_reader :local_state, :global_state, :tag, :tag_pos, :data, :usages

  def initialize(tag, data, tag_pos, global_state, local_state, usages)
    @tag = tag
    @data = data
    @tag_pos = tag_pos
    @global_state = global_state
    @local_state = local_state
    @usages = compact_usages(usages)
  end

  def state_table_without_pos(table)
    table.inject(Hash.new) do |new_hash,(key,value)|
      new_value = value.dup
      new_value.delete(:pos)

      new_hash[key] = new_value
      new_hash
    end
  end

  def without_pos!
    @local_state = state_table_without_pos(@local_state)
    @global_state = state_table_without_pos(@global_state)
    @usages = @usages.map {|x| x.without_pos}
    @tag_pos = nil
  end

  def usages_count
    usages.map { |x| x.count }.inject(0, :+)
  end

  def is_ambiguous?
    usages.count > 1
  end

  def compare_with_nils_last(a,b)
    if a.nil? and b.nil?
      return 0
    elsif a.nil?
      return 1
    elsif b.nil?
      return -1
    else
      return a <=> b
    end
  end

  def all_tags
    all_tags = global_state.merge(local_state)
    all_tags = all_tags.to_a

    usages.each do |u|
      all_tags.concat(u.tags)
    end

    all_tags.sort! do |(ak,av),(bk,bv)|
      compare_with_nils_last(av[:pos], bv[:pos])
    end
  end

  def [](tag)
    result = @local_state[tag] || @global_state[tag]
    result[:data] if result
  end

  def usage(i)
    @usages[i]
  end

  def includes_usage?(page, usage)
    p = unpack_num(self[HIDTags::USAGE_PAGE])
    p == page &&
      usages.any? {|x| x.includes_usage? usage}
  end

  def item_with_usage(ui)
    new_item = self.dup
    new_item.select_usage!(ui)
    unless ui == 0
      new_item.without_pos!
    end
    new_item
  end

  def compact_usages(usages)
    groups = usages.slice_when { |x,y| !(x.class == UsageImmediate and y.class == UsageImmediate) }
    groups.map do |g|
      if !g.empty? and g.first.class == UsageImmediate
        UsageImmediates.new(g.map {|x| x.item})
      else
        g.first
      end
    end
  end

  def select_usage!(ui)
    @usages = [@usages[ui]]

    @global_state = @global_state.dup

    report_count =
      (@global_state[HIDTags::REPORT_COUNT] = @global_state[HIDTags::REPORT_COUNT].dup)

    report_count[:data] =
      pack_num(report_count[:len], @usages.first.count)
  end

end

class HIDInfo
  def self.unpack_len(len)
    if len == 3 then 4 else len end
  end
  def self.pack_len(len)
    if len == 4 then 3 else len end
  end
  def self.parse_item(bytes)
    byte = bytes.read(1)[0].ord
    tag = HIDTags.tag_by_byte(byte & 0xfc)
    len = unpack_len(byte & 0x3)
    data = if len != 0
             bytes.read(len)
           end

    raise "Unknown item #{byte}" if tag.nil?

    [tag, len, data]
  end

  def self.tagstream(bytes)
    tag_stream = []
    until bytes.eof
      tag, len, data = parse_item(bytes)
      tag_stream << {
        :tag => tag.name,
        :len => len,
        :data => (unpack_num(data) if data)
      }
    end
    tag_stream
  end

  def self.parse(bytes)
    global_state = Hash.new
    local_state = Hash.new
    usages = Array.new

    result = []
    until bytes.eof
      tag_pos = bytes.pos
      tag, len, data = parse_item(bytes)
      if tag.is_global? or tag.is_local?
        target_hash = if   tag.is_global? then global_state
                      else local_state end

        item = { :data => data, :len => len, :pos => tag_pos }
        case tag
        when HIDTags::USAGE
          usages << UsageImmediate.new(item)
        when HIDTags::USAGE_MINIMUM
          min_item = item

          # pull one more, *must* be USAGE_MAXIMUM
          tag_pos = bytes.pos
          tag, len, data = parse_item(bytes)
          if tag != HIDTags::USAGE_MAXIMUM
            raise "Minimum/Maximum must occur in pairs"
          end
          max_item = { :data => data, :len => len, :pos => tag_pos }
          usages << UsageRange.new(min_item, max_item)
        else
          target_hash[tag] = item
        end
      elsif tag.is_main?
        result << MainItem.new(tag, data, tag_pos,
                               global_state.dup, local_state,
                               usages)
        local_state = Hash.new
        usages = Array.new
      end
    end
    result
  end

  def self.fix(items)
    result = []
    items.each do |item|
      if item.is_ambiguous?
        0.upto(item.usages.count - 1) do |u|
          result << item.item_with_usage(u)
        end
      else
        result << item
      end
    end
    result
  end

  def self.items_to_tag_stream(items)
    outpos = 0
    tag_stream = []

    global_state = Hash.new

    items.each do |item|
      item.all_tags.each do |tag, v|
        # if
        #  tag was part of input, and is next in line
        #  or tag state needs to override global state
        #  or tag is local
        # then stream it
        if v[:pos] && v[:pos] > outpos or
            (tag.is_global? && global_state[tag] != v[:data]) or
            tag.is_local? then

          global_state[tag] = v[:data] if tag.is_global?

          tag_stream << {
            :tag => tag.name,
            :len => v[:data].length,
            :data => (unpack_num(v[:data]) if v[:data])
          }
          outpos = v[:pos] if v[:pos]
        end
      end
      tag_stream << {
        :tag => item.tag.name,
        :len => (item.data.length if item.data) || 0,
        :data => (unpack_num(item.data) if item.data)
      }
      outpos = item.tag_pos if item.tag_pos
    end
    tag_stream
  end

  def self.fixed_tagstream(bytes)
    items_to_tag_stream(fix(parse(bytes)))
  end

  def self.encode(tagstream)
    result = ""
    tagstream.each do |t|
      tag = HIDTags.tag_by_name(t[:tag])
      len = pack_len(t[:len] || 0)
      byte = tag.byte | len
      result << byte.chr
      if len != 0
        data = pack_num(t[:len], t[:data])
        result << data
      end
    end
    result
  end

end
