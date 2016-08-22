require 'httparty'
class BidappApi
  API_URL = ''
    
  def api_call(url = '/', options)
    begin
      response = HTTParty.get(API_URL + url, headers: {"X-Hardware-MacAddress" => MAC_ADDR, "X-Hardware-Token" => TOKEN}, query: options)
      JSON.parse(response.body)
    rescue HTTParty::Error => e
      JSON.parse({error: "Error from #{API_URL + url}: #{e}"}.to_json)
    rescue StandardError => e
      JSON.parse({error: "Error contacting #{API_URL}: #{e}"}.to_json)
    end
  end
  
  def link_tag(url = '/', tag_address = '')
    response = HTTParty.post(API_URL + url, headers: {"X-Hardware-MacAddress" => MAC_ADDR, "X-Hardware-Token" => TOKEN}, body: {tag_address: tag_address})
    
  end
  
end
