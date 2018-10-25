require 'csv'

class Ranguba::FileReader

  def self.read(path, external_encoding=Encoding::UTF_8, default="")
    return default unless File.exist?(path)
    if external_encoding == Encoding::UTF_8
      File.open(path, "r:utf-8") {|file| file.read}
    else
      File.open(path, "r:#{external_encoding}:utf-8") {|file| file.read}
    end
  end

  def self.read_csv(path, external_encoding=Encoding::UTF_8)
    str = read(path, external_encoding)
    CSV.parse(str, skip_blanks: true) do |row|
      yield row
    end
  end

end
