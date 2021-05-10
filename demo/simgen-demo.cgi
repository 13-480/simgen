#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-
require './simgen.rb'
require 'cgi'

puts "Content-type: text/html\n\n"

cgi = CGI.new
lines = cgi.params['src'][0].split(/\n/)
psr = SimParser.new(lines)
psr.parse
gh = GenHTML.new(psr)
puts gh.gen_html
