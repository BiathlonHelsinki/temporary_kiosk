require 'httparty'

def parse_yaml(file)
  YAML::load(File.open(file))
end


class BidappApi
  
  def initialize
    @config = parse_yaml('temporary.yml')
  end
  
  def api_call(url = '/', options)
    begin
      response = HTTParty.get(@config['api_url'] + url, headers: {"X-Hardware-Name" => @config['name'], "X-Hardware-Token" => @config['token']}, query: options)
      JSON.parse(response.body)
    rescue HTTParty::Error => e
      JSON.parse({error: "Error from #{@config['api_url'] + url}: #{e}"}.to_json)
    rescue StandardError => e
      JSON.parse({error: "Error contacting #{@config['api_url']}: #{e}"}.to_json)
    end
  end
  
  def link_tag(url = '/', tag_id, securekey)

    response = HTTParty.post(@config['api_url'] + url, headers: {"X-Hardware-Name" => @config['name'], "X-Hardware-Token" => @config['token']}, body: {tag_address: tag_id, securekey: securekey})
    
  end
  
end
