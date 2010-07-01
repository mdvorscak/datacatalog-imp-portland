require File.dirname(__FILE__) + '/output'
require File.dirname(__FILE__) + '/puller'
#require File.dirname(__FILE__) + '/logger'

gem 'kronos', '>= 0.1.6'
require 'kronos'
require 'uri'
require 'mechanize'

class SourcePuller < Puller

  def initialize
    @metadata_master=[]
    @base_uri       = 'http://www.civicapps.org/datasets'
    @base           = 'http://www.civicapps.org'
    @details_folder = Output.dir  '/../cache/raw/source/detail'
    @index_data     = Output.file '/../cache/raw/source/index.yml'
    @index_html     = Output.file '/../cache/raw/source/index.html'
    @raw            = '/../cache/raw/source/'
   # @pull_log       = Output.file '/../cache/raw/source/pull_log.yml'
    Mechanize.html_parser = Nokogiri::HTML
    @agent = Mechanize.new
    super
  end



  #Iterates through each subset parsing it for metadata and combining that with the master set.
  def get_metadata
    login
    page=parse_one_page(@base_uri)
    #last=page.search("//div//ul[@class='pager']//li[@class='pager-last last']")
    #last_page_link=last.css("a").first["href"]
    #begin
    #  next_page=page.search("//div//ul[@class='pager']//li[@class='pager-next']")
    #    link=next_page.css("a").first
    #  if link
    #    link=link["href"]
    #    @current_page=@base+link
    #    puts "on page "+@current_page
    #    page=parse_one_page(@current_page)
    #  end
    #end while link!=last_page_link

    @metadata_master

  end

  def parse_one_page(link)
    page=@agent.get(link)
	  table_rows=page.search("//div//tbody//tr")

    table_rows.each do |row|
      a_tag=row.css("a").first
      file_type=row.css("td").last.inner_text
      file_type=U.single_line_clean(file_type)
      single_source=parse_one_source(a_tag["href"],file_type)
      @metadata_master<<single_source if single_source
    end
    page
  end

  def parse_one_source(link, download_type)
    clean_link=URI.unescape(link)
    clean_link.gsub!("/","_")
    raw_file= Output.file @raw+clean_link

    full_link=@base+link
    begin
      page=@agent.get(full_link)
    rescue 
      return nil
    end

    info={}
    rows=page.search("//div[@class='content']//table[@class='datasets-summary-table']//tr")
    rows.each do |row|
      td_tags=row.css("td")
      key=prepare_key(td_tags[0].inner_text)
      

      unless key==:keywords  
        a_tag=td_tags[1].css("a").first
        unless a_tag
          value=U.single_line_clean(td_tags[1].inner_text)
        else
          value=a_tag["href"]
        end
      else
        li_tags=td_tags[1].css("li")
        value=[]
        li_tags.each {|tag| value<<tag.inner_text}
      end
      info[key]=value
    end
    dl=page.search("//div[@class='download_dataset']//form")
    download_link=dl.css("input").first
    if download_link  
      download_link=download_link["onclick"] 
      download_link.gsub!("window.open","")
      download_link.gsub!("('","")
      download_link.gsub!("')","")
      info[:download]=download_link
    end
    info[:url]=full_link
    info[:download_type]=download_type
    info
  end



	def parse_metadata(metadata)
    m={ :released=>Kronos.parse(metadata.delete(:date_released)).to_hash,
        :frequency=>metadata.delete(:frequency),
        :url=>metadata.delete(:url),
        :description=>metadata.delete(:description),
        :organization=>{:name=>metadata.delete(:agency),
                        :home_url=>metadata.delete(:agency_program)},
    }

    dl_type=metadata.delete(:download_type)
    key=translate_download_to_key(dl_type)
    m[:downloads]=[{:url=>metadata.delete(:download),:format=>key}]

    if dl_type=="Web Service"
      source_type="api"
    else
      source_type="dataset"
    end


    m[:source_type]=source_type
    m[:catalog_name]="Portland Oregon Data Catalog"
    m[:catalog_url]=@base_uri

    metadata.delete(:sub_agency)

    add_to_custom(m,"last_updated","last update to data set",
                  "string",metadata.delete(:date_updated))
    add_to_custom(m,"tags","tags for the data set","array",
                  metadata.delete(:keywords))
    metadata.each do |key,value|
      type=value.class.to_s
      add_to_custom(m,key.to_s,key.to_s,type.downcase,value)
    end
    m
	end

  private

  def translate_download_to_key(download)
    case download
    when "Shapefile"   : "shp"
    when "XML/RSS"     : "rss"
    when "KML/KMZ"     : "kml"
    when "CSV/Text"    : "csv"
    when "Other"       : "html"
    when "Web Service" : "html"
    else                 "html"
    end
  end

  def login
    page=@agent.get('https://www.civicapps.org/user/login')
    form=page.forms.last
    form['name']='mdvorscak'
    form['pass']='sunlight_labs'
    form.submit
  end

  def prepare_key(key)
    k=U.single_line_clean(key).downcase
    k.gsub!(" ","_")
    k.gsub!("-","_")
    k.intern
  end

  def add_to_custom(metadata,label,description,type,value)
    if metadata[:custom].nil?
      metadata[:custom]={}
    end
    num=metadata[:custom].size.to_s
    metadata[:custom][num]={:label=>label,:description=>description,:type=>type,:value=>value}
  end

end
