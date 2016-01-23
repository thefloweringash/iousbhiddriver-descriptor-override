require 'spec_helper'
require 'base64'

## The desciptor that inspired all of this

EXAMPLE_DESCRIPTOR = Base64.decode64(
  %q|BQEJBqEBBQgZASkDFQAlAXUBlQORApUFkQEFBxngKeeVCIECGQQpJwktCS4J
     LwkwCTEJMwk0CTYJNwk4CTUJLAk5CSsJSglLCUwJTQlOCSiVOIECwA==|)

EXAMPLE_TAGSTREAM =
  [{:tag => "USAGE_PAGE",      :len => 1, :data => 1   },
   {:tag => "USAGE",           :len => 1, :data => 6   },
   {:tag => "COLLECTION",      :len => 1, :data => 1   },
   {:tag => "USAGE_PAGE",      :len => 1, :data => 8   },
   {:tag => "USAGE_MINIMUM",   :len => 1, :data => 1   },
   {:tag => "USAGE_MAXIMUM",   :len => 1, :data => 3   },
   {:tag => "LOGICAL_MINIMUM", :len => 1, :data => 0   },
   {:tag => "LOGICAL_MAXIMUM", :len => 1, :data => 1   },
   {:tag => "REPORT_SIZE",     :len => 1, :data => 1   },
   {:tag => "REPORT_COUNT",    :len => 1, :data => 3   },
   {:tag => "OUTPUT",          :len => 1, :data => 2   },
   {:tag => "REPORT_COUNT",    :len => 1, :data => 5   },
   {:tag => "OUTPUT",          :len => 1, :data => 1   },
   {:tag => "USAGE_PAGE",      :len => 1, :data => 7   },
   {:tag => "USAGE_MINIMUM",   :len => 1, :data => 224 },
   {:tag => "USAGE_MAXIMUM",   :len => 1, :data => 231 },
   {:tag => "REPORT_COUNT",    :len => 1, :data => 8   },
   {:tag => "INPUT",           :len => 1, :data => 2   },
   {:tag => "USAGE_MINIMUM",   :len => 1, :data => 4   },
   {:tag => "USAGE_MAXIMUM",   :len => 1, :data => 39  },
   {:tag => "USAGE",           :len => 1, :data => 45  },
   {:tag => "USAGE",           :len => 1, :data => 46  },
   {:tag => "USAGE",           :len => 1, :data => 47  },
   {:tag => "USAGE",           :len => 1, :data => 48  },
   {:tag => "USAGE",           :len => 1, :data => 49  },
   {:tag => "USAGE",           :len => 1, :data => 51  },
   {:tag => "USAGE",           :len => 1, :data => 52  },
   {:tag => "USAGE",           :len => 1, :data => 54  },
   {:tag => "USAGE",           :len => 1, :data => 55  },
   {:tag => "USAGE",           :len => 1, :data => 56  },
   {:tag => "USAGE",           :len => 1, :data => 53  },
   {:tag => "USAGE",           :len => 1, :data => 44  },
   {:tag => "USAGE",           :len => 1, :data => 57  },
   {:tag => "USAGE",           :len => 1, :data => 43  },
   {:tag => "USAGE",           :len => 1, :data => 74  },
   {:tag => "USAGE",           :len => 1, :data => 75  },
   {:tag => "USAGE",           :len => 1, :data => 76  },
   {:tag => "USAGE",           :len => 1, :data => 77  },
   {:tag => "USAGE",           :len => 1, :data => 78  },
   {:tag => "USAGE",           :len => 1, :data => 40  },
   {:tag => "REPORT_COUNT",    :len => 1, :data => 56  },
   {:tag => "INPUT",           :len => 1, :data => 2   },
   {:tag => "END_COLLECTION",  :len => 0, :data => nil }]

RSpec.describe HIDInfo do
  describe "#tagstream" do
    it "parses an empty descriptor" do
      tagstream = HIDInfo.tagstream(StringIO.new(""))
      expect(tagstream).to eq([])
    end

    it "parses a complete descriptor" do
      expect(HIDInfo.tagstream(StringIO.new(EXAMPLE_DESCRIPTOR))).to(
        eq(EXAMPLE_TAGSTREAM))
    end
  end

  describe "#encode" do
    it "encodes a complete descriptor" do
      expect(HIDInfo.encode(EXAMPLE_TAGSTREAM)).to(
        eq(EXAMPLE_DESCRIPTOR))
    end
  end

  describe "#parse" do
    it "parses a full descriptor" do
      items = HIDInfo.parse(StringIO.new(EXAMPLE_DESCRIPTOR))
      expect(items.count).to eq(6) # COLLECTION / OUTPUT *2 / INPUT * 2 / END_COLLECTION
      expect(items[4].usages_count).to eq(56) # 4-39= 36 + 20 literals
    end
  end

  describe "#fix" do
    it "generates new items from composite items" do
      mainitem =
        MainItem.new(
        "INPUT", "\x2", nil,
        {HIDTags::REPORT_COUNT => {
           :tag => "REPORT_COUNT", :len => 1, :data => "\x9"
         }},
        {},
        [UsageImmediate.new(
           {:tag => "USAGE", :len => 1, :data => "\x1" }),
         UsageImmediate.new(
           {:tag => "USAGE", :len => 1, :data => "\x2" }),
         UsageImmediate.new(
           {:tag => "USAGE", :len => 1, :data => "\x3" }),
         UsageRange.new(
           {:tag => "USAGE_MINIMUM", :len => 1, :data => "\x4"},
           {:tag => "USAGE_MAXIMUM", :len => 1, :data => "\x6"}
         ),
         UsageImmediate.new(
           {:tag => "USAGE", :len => 1, :data => "\x7" }),
         UsageImmediate.new(
           {:tag => "USAGE", :len => 1, :data => "\x8" }),
         UsageRange.new(
           {:tag => "USAGE_MINIMUM", :len => 1, :data => "\x9"},
           {:tag => "USAGE_MAXIMUM", :len => 1, :data => "\xa"}
         ),
         UsageImmediate.new(
           {:tag => "USAGE", :len => 1, :data => "\xb" }),
        ])
      fixed = HIDInfo.fix([mainitem])
      expect(fixed.count).to eq(5)

      (i1, i2, i3, i4, i5) = fixed.map{|x| x.usage(0) }

      expect(i1).to be_a(UsageImmediates)
      expect(i1.values).to eq([1,2,3])

      expect(i2).to be_a(UsageRange)
      expect(i2.values).to eq([4,5,6])

      expect(i3).to be_a(UsageImmediates)
      expect(i3.values).to eq([7,8])

      expect(i4).to be_a(UsageRange)
      expect(i4.values).to eq([9,10])

      expect(i5).to be_a(UsageImmediates)
      expect(i5.values).to eq([11])
    end
  end
end

RSpec.describe MainItem do
  describe "#compact_usages" do
    it "coalesces adjacent immediates" do
      # this happens as part of the constructor
      mainitem = MainItem.new(
        nil, nil, nil, {}, {},
        [UsageImmediate.new(
           {:tag => "USAGE", :len => 1, :data => "\x1" }),
         UsageImmediate.new(
           {:tag => "USAGE", :len => 1, :data => "\x2" }),
         UsageImmediate.new(
           {:tag => "USAGE", :len => 1, :data => "\x3" }),
         UsageRange.new(
           {:tag => "USAGE_MINIMUM", :len => 1, :data => "\x4"},
           {:tag => "USAGE_MAXIMUM", :len => 1, :data => "\x6"}
         ),
         UsageImmediate.new(
           {:tag => "USAGE", :len => 1, :data => "\x7" }),
         UsageImmediate.new(
           {:tag => "USAGE", :len => 1, :data => "\x8" }),
         UsageImmediate.new(
           {:tag => "USAGE", :len => 1, :data => "\x9" }),
        ])

      expect(mainitem.usage(0)).to be_a(UsageImmediates)
      expect(mainitem.usage(0).values).to eq([1,2,3])

      expect(mainitem.usage(1)).to be_a(UsageRange)
      expect(mainitem.usage(1).min).to eq(4)
      expect(mainitem.usage(1).max).to eq(6)
      expect(mainitem.usage(1).values).to eq([4,5,6])

      expect(mainitem.usage(2)).to be_a(UsageImmediates)
      expect(mainitem.usage(2).values).to eq([7,8,9])
    end
  end
end

## TODO tests for position handling
