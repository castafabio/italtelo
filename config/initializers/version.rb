module PrintingSolutionsV2
  module VERSION
    def self.to_s
      `git tag`.split("\n").sort_by { |tag| ("%d%03d%03d" % tag.gsub('v', '').split('.')).to_i }.last
    end
  end
end
