require_relative './no_manifest_error'

module OPenn
  OPENN_DATA_URL = 'https://openn.library.upenn.edu/Data'.freeze
  # https://openn.library.upenn.edu/Data/0020/Data/WaltersManuscripts/ManuscriptDescriptions/
  WALTERS_TEI_URL = "#{OPENN_DATA_URL}/0020/Data/WaltersManuscripts/ManuscriptDescriptions"
  COLLECTIONS_CSV = "#{OPENN_DATA_URL}/collections.csv"
  MANIFEST_NAMES = %w{ manifest-sha1.txt manifest-md5.txt }.freeze

  ##
  # Return true if the url yields a 200 response code
  def self.url_exists? url_string
    url = URI.parse(url_string)
    req = Net::HTTP.new(url.host, url.port)
    req.use_ssl = true if url_string =~ /\Ahttps/
    res = req.request_head(url.path)
    res.code == '200'
  end

  ##
  # Get the manifest for the given manuscript.
  #
  def self.find_manifest_url object_path
    MANIFEST_NAMES.map { |p|
      sprintf "%s/%s/%s", OPENN_DATA_URL, object_path, p
    }.find { |url| url_exists? url }
  end

  def self.find_tei_url object_path
    basename = File.basename object_path
    tei_url = nil
    if object_path.start_with? '0020'
      # https://openn.library.upenn.edu/Data/0020/Data/WaltersManuscripts/ManuscriptDescriptions/W4_tei.xml
      tei_url = sprintf "%s/%s_tei.xml", WALTERS_TEI_URL, basename
    else
      # https://openn.library.upenn.edu/Data/0022/mssHM_9999/data/mssHM_9999_TEI.xml
      tei_url = sprintf "%s/%s/data/%s_TEI.xml", OPENN_DATA_URL, object_path, basename
    end
    return tei_url if url_exists? tei_url
  end

  def self.get_repo_number path
    path.split(/\//, 2).first
  end

  ##
  # Get the number of master images associated with the object by counting them
  # in the manifest-sha1.txt or manifest-md5.txt file.
  #
  # Openn manifest-sha1.txt format is:
  #
  #   0deb0ba96a5a5b67faa2bafae39752ad50184cc4  data/master/6837_0112.tif
  #   34416e6d8fdb9d309b5a6f016f53da08e6de9d15  data/web/6837_0165_web.jpg.xmp
  #
  # Digital Walters manifest-md5.txt format is:
  #
  #   bf2980cf7c91b210cd45d94665de8158 data/W.168/thumb/W168_000204_thumb.jpg
  #   8b8d15a7d1ed72bd0964ecce0c2b9601 data/W.168/sap/W168_000012_sap.jpg
  #   384055e9d9a5f153f5eb0292b0d56502 data/W.168/master/W168_000229_600.tif
  #
  # @param [String] object_path path to the object, relative to the Openn '/Data'
  #                 directory; e.g., '0001/ljs103'
  # @return [Integer]
  def self.get_page_count object_path
    manifest_uri = find_manifest_url object_path
    raise NoManifestError, "No manifest found for #{object_path}" unless manifest_uri
    manifest = URI.open(manifest_uri).readlines.map &:chomp

    # count the TIFFs or JPEGs in the `data/master` or `data/<SHELFMARK>/master`
    # subdirectory
    manifest.grep(%r{data/(\w[-\w.]+/)?master/.+\.(tif|jpg)$}).size
  end

  def self.get_language object_path
    url = find_tei_url object_path
    return unless url
    #  78   frag = IO.read File.join(subdirectory, 'data/metadata.xml'), 8192
    #  79   frag =~ /<dc:title>(.+)<\/dc:title>/m
    #  80   "#$1".strip
    URI.open(url).read(1<<16) =~ %r{mainLang="([^"]+)"}
    match = $1
    STDERR.puts "WARNING: No mainLang found for #{object_path}" unless match
    match && match.strip
  end

  def self.get_collections_data
    hash = {}
    CSV.parse URI.open(COLLECTIONS_CSV).read, headers: true do |row|
      hash[row['repository_id']] = row.to_h
    end
    hash
  end

  def self.csv_url repo_number
    sprintf "%s/%s_contents.csv", OPENN_DATA_URL, repo_tag(repo_number)
  end

  def self.repo_tag repo_number
    repo_number =~ /\A\d+\Z/ ? sprintf("%04d", repo_number) : repo_number
  end

  def self.get_date_added csv_row
    csv_row['added']
  end

  def self.get_created csv_row
    csv_row['created'] || csv_row['document_created']
  end

  def self.get_updated csv_row
    csv_row['updated'] || csv_row['document_updated']
  end
end
