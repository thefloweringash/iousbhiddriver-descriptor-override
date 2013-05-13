def unpack_num(bytes)
  bytes.unpack("H*").first.to_i(16)
end
def pack_num(num)
  str = num.to_s 16
  if str.length % 2 == 1
    str = "0" + str
  end
  [str].pack("H*")
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



class MainItem
  attr_reader :local_state, :global_state, :tag, :tag_pos, :data

  def initialize(tag, data, tag_pos, global_state, local_state)
    @tag = tag
    @data = data
    @tag_pos = tag_pos
    @global_state = global_state
    @local_state = local_state
  end

  def copy_state_table(table)
    table.inject(Hash.new) do |new_hash,(key,value)|
      if key == HIDTags::USAGE
        new_value = Array.new
        value.each do |usage|
          new_usage = usage.dup
          new_usage.delete :pos
          new_value << new_usage
        end
      else
        new_value = value.dup
        new_value.delete :pos
      end
      new_hash[key] = new_value
      new_hash
    end
  end

  def initialize_copy(other)
    @local_state = copy_state_table(other.local_state)
    @global_state = copy_state_table(other.global_state)
    @tag_pos = nil
  end

  def usage_range
    max_item = @local_state[HIDTags::USAGE_MAXIMUM]
    min_item = @local_state[HIDTags::USAGE_MINIMUM]
    if max_item and min_item
      max = unpack_num(max_item[:data])
      min = unpack_num(min_item[:data])
      return (min..max)
    end
  end

  def immediate_usages
    usages = @local_state[HIDTags::USAGE]
    if usages
      usages.map { |x| unpack_num(x[:data]) }
    end
  end

  def usages_count
    total = 0

    r = usage_range
    total += (r.max - r.min) + 1 if r

    usages = @local_state[HIDTags::USAGE]
    total += usages.length if usages

    total
  end

  def is_ambiguous?
    [
     @local_state[HIDTags::USAGE_MINIMUM],
     @local_state[HIDTags::USAGE_MAXIMUM],
     @local_state[HIDTags::USAGE],
    ].all?
  end

  def remove_range!
    @local_state.delete HIDTags::USAGE_MAXIMUM
    @local_state.delete HIDTags::USAGE_MINIMUM
    @global_state[HIDTags::REPORT_COUNT][:data] = pack_num(usages_count)
  end

  def remove_immediate!
    @local_state.delete HIDTags::USAGE
    @global_state[HIDTags::REPORT_COUNT][:data] = pack_num(usages_count)
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
    immediate_usages = all_tags.delete HIDTags::USAGE
    all_tags = all_tags.to_a
    if immediate_usages
      immediate_usages.each do |details|
        all_tags << [HIDTags::USAGE, details]
      end
    end
    all_tags.sort! do |(ak,av),(bk,bv)|
      compare_with_nils_last(av[:pos], bv[:pos])
    end
  end

  def [](tag)
    result = @local_state[tag] || @global_state[tag]
    result[:data] if result
  end

  def includes_usage?(page, usage)
    p = unpack_num(self[HIDTags::USAGE_PAGE])
    r = usage_range
    i = immediate_usages
    p == page &&
      ((r.include? usage if r) ||
       (i.include? usage if i))
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

    result = []
    until bytes.eof
      tag_pos = bytes.pos
      tag, len, data = parse_item(bytes)
      if tag.is_global? or tag.is_local?
        target_hash = if   tag.is_global? then global_state
                      else local_state end

        if tag == HIDTags::USAGE
          (target_hash[tag] ||= []) << { :data => data, :pos => tag_pos }
        else
          target_hash[tag] = { :data => data, :pos => tag_pos }
        end
      elsif tag.is_main?
        result << MainItem.new(tag, data, tag_pos,
                               global_state.dup, local_state)
        local_state = Hash.new
      end
    end
    result
  end

  def self.fix(items)
    result = []
    items.each do |item|
      if item.is_ambiguous?
        range_item = item.dup
        range_item.remove_immediate!
        result << range_item
        # puts "range_item="
        # pp range_item

        immediate_item = item.dup
        immediate_item.remove_range!
        result << immediate_item
        # puts "immediate_item="
        # pp immediate_item
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
        data = pack_num(t[:data])
        result << data
      end
    end
    result
  end

end
