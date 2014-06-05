require 'json'
require "net/http"
require "uri"

@email="foo@bar"
@api_key="api key"
@deployment="deployment name"

@uri = URI.parse("https://wwws.appfirst.com" )

def get_appfirst_server_id (host)
  http = Net::HTTP.new(@uri.host, @uri.port)
  http.use_ssl = true
  http.start { |http|
    req = Net::HTTP::Get.new("/api/servers/?hostname=#{host}")
    req.basic_auth(@email, @api_key)
    response = http.request(req)
    hash= JSON.parse response.body
    return hash["data"].first["id"]
  }
end

def create_appfirst_server_tag (tag, servers)
  http = Net::HTTP.new(@uri.host, @uri.port)
  http.use_ssl = true
  http.start { |http|
    req = Net::HTTP::Post.new("/api/server_tags/")
    req.set_form_data "name" => tag, "servers" => servers.to_s
    req.basic_auth(@email, @api_key)
    response = http.request(req)
  }
end

def delete_appfirst_server_tag (id)
  http = Net::HTTP.new(@uri.host, @uri.port)
  http.use_ssl = true
  http.start { |http|
    req = Net::HTTP::Delete.new("/api/server_tags/#{id}/")
    req.basic_auth(@email, @api_key)
    response = http.request(req)
  }
end

#return array of hashes:
#[  {   "resource_uri": "x", "id": x, "name": "x",     "servers": [ x] }, ...]

def appfirst_server_tags
  http = Net::HTTP.new(@uri.host, @uri.port)
  http.use_ssl = true
  http.start { |http|
    req = Net::HTTP::Get.new("/api/server_tags/")
    req.basic_auth(@email, @api_key)
    response = http.request(req)
    hash= JSON.parse response.body
    return hash["data"]
  }
end

def delete_all_tags
  appfirst_server_tags.each { |tag| delete_appfirst_server_tag tag["id"] }
end

output=`bosh vms #{@deployment} --details`
abort "error running bosh vms  #{deployment}" unless $?.success?

lines=output.split("\n").select { |l| l.match(/^\|/) && (! l.match( /Job|unknow/) ) }
vms=lines.map { |line|
  f=line.split("|")
  { job: f[1].strip.split("/").first, index: f[1].strip.split("/").last,  agent_id: f[6].strip}
}

tags={}
vms.each {  |vm|
  tag = vm[:job]
  id= get_appfirst_server_id vm[:agent_id]
  if tags.has_key? tag
    tags[tag] << id
  else
    tags[tag]=[id]
  end
}
p tags
print "\n Warning: existing server tags on AppFirst will be overwritten! Press Ctrl-C to stop, press Enter to continue.\n"
gets
delete_all_tags
tags.each_pair { |tag, servers| create_appfirst_server_tag tag, servers}
