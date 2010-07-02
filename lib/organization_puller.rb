require File.dirname(__FILE__) + '/output'
require File.dirname(__FILE__) + '/puller'
#require File.dirname(__FILE__) + '/logger'

require 'uri'

class OrganizationPuller < Puller

  @@metadata_master=[]
  def initialize
    @base_uri       = 'http://www.civicapps.org/about/data-providers/'
    @uri            = 'https://wiki.state.ma.us'
    @details_folder = Output.dir  '/../cache/raw/organization/detail'
    @index_data     = Output.file '/../cache/raw/organization/index.yml'
    @index_html     = Output.file '/../cache/raw/organization/index.html'
   # @pull_log       = Output.file '/../cache/raw/source/pull_log.yml'
    super
  end


  #Iterates through each subset parsing it for metadata and combining that with the master set.
  def get_metadata
    doc=U.parse_html_from_file_or_uri(@base_uri,@index_html,:force_fetch=>true)
    names=doc.xpath("//div[@id='main-content']//h5")
    links=doc.xpath("//div[@id='main-content']//p//a")
    links.size.times do |x|
      @@metadata_master<<{:name=>names[x].inner_text,:home_url=>links[x]["href"],:url=>links[x]["href"]}
    end
    @@metadata_master
  end

# Returns as many fields as possible:
  #
  #   property :name
  #   property :names
  #   property :acronym
  #   property :org_type
  #   property :description
  #   property :slug
  #   property :url
  #   property :interest
  #   property :level
  #   property :source_count
  #   property :custom
  #
	def parse_metadata(metadata)
      metadata[:catalog_name]="Portland Oregon Data Catalog"
      metadata[:catalog_url]=@base_uri
      metadata[:org_type]="governmental"
      metadata[:organization]={:name=>"Portland"}
    metadata
	end

  def self.add_org(org_name,org_url)
    found=false
    @@metadata_master.each do |index|
      found=index.find {|key,val| val==org_name or val==org_url}
      break if found
    end
    @@metadata_master<<{:name=>org_name,:home_url=>org_url,:url=>org_url} unless found
  end
end
