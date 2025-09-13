# lib/facter_conf_helper.rb
require 'fileutils'
require 'facter'

class FacterConfHelper
  attr_reader :file_path

  DEFAULT_PATHS = {
    windows: 'C:/ProgramData/PuppetLabs/facter/facter.conf',
    linux: '/etc/puppetlabs/facter/facter.conf'
  }.freeze

  def initialize(file_path: nil)
    @file_path = file_path || default_path
    ensure_file
  end

  ##########################
  # Public methods
  ##########################

  def add_ttls(ttls_hash = {})
    ttls_hash.each { |fact, duration| add_ttl(fact, duration) }
  end

  def add_blocklists(items = [])
    items.each { |item| add_blocklist(item) }
  end

  def current_ttls
    content = File.read(file_path)
    content.scan(/\{\s*"([^"]+)"\s*:/).flatten
  end

  def current_blocklist
    content = File.read(file_path)
    content.scan(/blocklist\s*:\s*\[([^\]]*)\]/m).flatten.first.to_s.scan(/"([^"]+)"/).flatten
  end

  # ✅ Now flattens nested facts before comparison
  def sync_with_facter!
    facts = flatten_facts(Facter.to_hash)
    remove_ttls(current_ttls - facts)
    remove_blocklists(current_blocklist - facts)
  end

  ##########################
  # Private methods
  ##########################

  private

  def add_ttl(fact, duration)
    content = File.read(file_path)
    ttl_block = content[/ttls\s*:\s*\[(.*?)\]/m, 1] || ""
    ttl_lines = ttl_block.scan(/\{.*?\}/m)
    ttl_lines.reject! { |line| line =~ /#{Regexp.escape(fact)}/ }
    ttl_lines << "{ \"#{fact}\" : #{duration} }"
    new_ttls = ttl_lines.join(",\n        ")
    new_content = content.sub(/ttls\s*:\s*\[.*?\]/m, "ttls : [\n        #{new_ttls}\n    ]")
    File.write(file_path, new_content)
  end

  def add_blocklist(item)
    content = File.read(file_path)
    blocklist_match = content[/blocklist\s*:\s*\[(.*?)\]/m, 1] || ""
    items = blocklist_match.scan(/"(.*?)"/).flatten
    items << item unless items.include?(item)
    new_blocklist = items.map { |i| "\"#{i}\"" }.join(", ")
    new_content = content.sub(/blocklist\s*:\s*\[.*?\](,?)/m, "blocklist : [ #{new_blocklist} ],")
    File.write(file_path, new_content)
  end

  def remove_ttl(fact)
    content = File.read(file_path)
    new_content = content.gsub(/\{\s*"#{Regexp.escape(fact)}"\s*:\s*.*?\}/, '').gsub(/,\s*\]/, ']')
    File.write(file_path, new_content)
  end

  def remove_blocklist(item)
    content = File.read(file_path)
    new_content = content.gsub(/"#{Regexp.escape(item)}"(,?)/, '').gsub(/,\s*\]/, ']')
    File.write(file_path, new_content)
  end

  def default_path
    Gem.win_platform? ? DEFAULT_PATHS[:windows] : DEFAULT_PATHS[:linux]
  end

  def ensure_file
    return if File.exist?(file_path)
    FileUtils.mkdir_p(File.dirname(file_path))
    default_content = <<~HOCON
      facts : {
          blocklist : [],
          ttls : []
      }
    HOCON
    File.write(file_path, default_content)
  end

  # 🔑 Flatten nested fact hash into dot-notation keys
  def flatten_facts(hash, prefix = "")
    hash.flat_map do |k, v|
      full_key = prefix.empty? ? k.to_s : "#{prefix}.#{k}"
      if v.is_a?(Hash)
        [full_key] + flatten_facts(v, full_key)
      else
        full_key
      end
    end
  end
end
