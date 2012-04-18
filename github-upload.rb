#!/usr/bin/env ruby

# Die if something goes wrong
def die(msg); puts(msg); exit!(1); end

# Login credentials
login = `git config --get github.user`.chomp
token = `git config --get github.passwd`.chomp

# We extend Pathname a bit to get the content type
require 'pathname'
class Pathname; def type; `file -Ib #{to_s}`.chomp; end; end

# The file we want to upload
file = Pathname.new(ARGV[0])

# Repository to which to upload the file
repo = ARGV[1] || `git config --get remote.origin.url`.match(/git@github.com:(.+?)\.git/)[1]

# Establish a HTTPS connection to github
require 'net/https'
uri = URI.parse("https://api.github.com/repos/#{repo}/downloads")
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

# Request a signature and that stuff so that we can upload the file to S3
req = Net::HTTP::Post.new(uri.path)
req.basic_auth(login, token)

# Check if something went wrong
require 'json'
res = http.request(req, {
  'name' => file.basename.to_s, 'size' => file.size.to_s,
  'content_type' => file.type.gsub(/;.*/, '')
}.to_json)

die("File already exists.") if res.class == Net::HTTPClientError
die("Github doens't want us to upload the file.") unless res.class == Net::HTTPCreated

# Parse the body, it's json
info = JSON.parse(res.body)

# Open a connection to S3
uri = URI.parse(info['s3_url'])
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

# Yep, ruby net/http doesn't support multipart. Write our own multipart generator.
def urlencode(str)
  str.gsub(/[^a-zA-Z0-9_\.\-]/n) {|s| sprintf('%%%02x', s[0].to_i) }
end

def build_multipart_content(params)
  parts, boundary = [], "#{rand(1000000)}-we-are-all-doomed-#{rand(1000000)}"

  params.each do |name, value|
    data = []
    if value.is_a?(Pathname) then
      data << "Content-Disposition: form-data; name=\"#{urlencode(name.to_s)}\"; filename=\"#{value.basename}\""
      data << "Content-Type: #{value.type}"
      data << "Content-Length: #{value.size}"
      data << "Content-Transfer-Encoding: binary"
      data << ""
      data << value.read
    else
      data << "Content-Disposition: form-data; name=\"#{urlencode(name.to_s)}\""
      data << ""
      data << value
    end

    parts << data.join("\r\n") + "\r\n"
  end

  [ "--#{boundary}\r\n" + parts.join("--#{boundary}\r\n") + "--#{boundary}--", {
    "Content-Type" => "multipart/form-data; boundary=#{boundary}"
  }]
end

# The order of the params is important, the file needs to go as last!
res = http.post(uri.path, *build_multipart_content({
  'key' => info['path'], 'acl' => info['acl'], 'success_action_status' => 201,
  'Filename' => info['name'], 'AWSAccessKeyId' => info['accesskeyid'],
  'Policy' => info['policy'], 'signature' => info['signature'],
  'Content-Type' => info['mime_type'], 'file' => file
}))

die("S3 is mean to us.") unless res.class == Net::HTTPCreated

# Print the URL to the file to stdout.
puts "#{info['s3_url']}#{info['path']}"
