require "nokogiri"
require "fileutils"
require "digest/sha1"

module JGraphs
	class Graph
		Defaults = {
			:encoding => "utf-8",
			:renderer => "dot",
			:scale => 1.0
		}.freeze
		
		Flags = %w[].freeze
		FloatOptions = %w[scale].freeze
		IntegerOptions = %w[].freeze
		StringOptions = %w[encoding renderer].freeze
		
		NumberOptions = (FloatOptions + IntegerOptions).freeze
		ValueOptions = (NumberOptions + StringOptions).freeze
		Options = (Flags + ValueOptions).freeze
		
		FloatOptions.each { |key| define_method(key) { @options[key.to_sym].to_f } }
		IntegerOptions.each { |key| define_method(key) { @options[key.to_sym].to_i } }
		(Options - NumberOptions - %w[renderer]).each { |key| define_method(key) { @options[key.to_sym] } }
		
		GraphvizRenderers = %w[dot neato twopi circo fdp sfdp patchwork].freeze
		TeXRenderers = %w[tex latex pdftex pdflatex xetex xelatex luatex lualatex].freeze
		Renderers = (GraphvizRenderers + TeXRenderers + %w[mscgen plantuml shaape]).freeze
		
		attr_reader :site
		
		attr_accessor :source, :file
		
		def initialize site, options = { }
			@renderpaths = { }
			
			@site, @options = site, options.dup
			
			merge_site_options
			
			@options.merge!(self.class::Defaults) { |_, option, _| option }
			@options.keep_if { |key, _| self.class::Options.include? key.to_s }
		end
		
		def renderer
			raise ArgumentError.new "invalid renderer value" unless Renderers.include? @options[:renderer].to_s.downcase
			
			@options[:renderer].to_s.downcase.to_sym
		end
		
		def code
			source.strip
		end
		
		def svg_xml
			return File.read cache_path if File.exist? cache_path
			
			svg = generate_svg
			
			FileUtils.mkdir_p File.dirname cache_path
			File.write cache_path, svg if svg && !svg.empty?
			
			svg
		end
		
		def hash
			if TeXRenderers.include? renderer.to_s
				@hash ||= Digest::SHA1.hexdigest "#{renderer} #{renderer_arguments(renderer) * " "} #{renderer_arguments(:dvisvgm) * " "}\n\n#{code}"
			else
				@hash ||= Digest::SHA1.hexdigest "#{renderer} #{renderer_arguments(renderer) * " "}\n\n#{code}"
			end
		end
		
		def cache_path
			File.join site.source, ".jgraphs-cache", "#{hash}.svg"
		end
		
		def generate_svg
			unless has_renderer renderer
				STDERR.puts "You are missing an executable required for jekyll-graphs."
				raise LoadError.new "Missing dependency: #{renderer}"
			end
			
			return generate_svg_tex if TeXRenderers.include? renderer.to_s
			
			chdir = File.join site.source, file ? File.dirname(file) : dir
			FileUtils.mkdir_p chdir
			
			IO.popen renderer_cmd(renderer), "r+", :chdir => chdir do |pipe|
				pipe.binmode
				
				pipe.write code
				pipe.close_write
				
				pipe.read
			end
		end
		private :generate_svg
		
		def generate_svg_tex
			unless has_renderer :dvisvgm
				STDERR.puts "You are missing an executable required for jekyll-graphs."
				raise LoadError.new "Missing dependency: dvisvgm"
			end
			
			Dir.mktmpdir "tex" do |dir|
				tex_cmd = renderer_cmd renderer
				tex_cmd << "-output-directory" << dir unless renderer == :luatex || renderer == :lualatex
				tex_cmd << "--output-directory=#{dir}" if renderer == :luatex || renderer == :lualatex
				tex_cmd << tex_path = file || "#{dir}/#{hash}.tex"
				
				dvi_path = "#{dir}/#{File.basename tex_path, ".*"}.#{renderer == :xetex || renderer == :xelatex ? "xdv" : "dvi"}"
				
				chdir = File.join site.source, file ? File.dirname(file) : dir
				FileUtils.mkdir_p chdir

				File.write tex_path, code unless file
				
				#Process.wait IO.popen(tex_cmd, :err => [:child, :out], :chdir => chdir).pid
				puts IO.popen(tex_cmd, :err => [:child, :out], :chdir => chdir).read
				
				raise IOError.new "Failed to convert #{tex_path} to dvi" unless File.exist? dvi_path
				
				IO.popen(renderer_cmd(:dvisvgm) << dvi_path).read
			end
		end
		private :generate_svg_tex
		
		def merge_site_options
			unless site.config["jgraphs"].nil?
				@options.merge!(Jekyll::Utils.symbolize_hash_keys site.config["jgraphs"]) { |_, option, _| option }
				
				unless site.config["jgraphs"]["renderers"].nil?
					@renderpaths.merge!(Jekyll::Utils.symbolize_hash_keys site.config["jgraphs"]["renderers"]) { |_, _, option| option }
				end
			end
			
			@options[:encoding] ||= site.config["encoding"]
		end
		private :merge_site_options
		
		def has_renderer renderer
			system "which #{renderer_path renderer} >/dev/null 2>&1"
		end
		private :has_renderer
		
		def renderer_cmd renderer
			cmd = [renderer_path(renderer)]
			
			if @renderpaths[renderer].kind_of?(Array) && @renderpaths[renderer].length > 1
				cmd.concat @renderpaths[renderer][1..-1]
			end
			
			cmd.concat renderer_arguments renderer
		end
		private :renderer_cmd;
		
		def renderer_path renderer
			[*(@renderpaths[renderer] || [])][0] || renderer.to_s
		end
		private :renderer_path
		
		def renderer_arguments renderer
			return renderer_arguments_tex renderer if TeXRenderers.include? renderer.to_s
			return renderer_arguments_dvisvgm if renderer == :dvisvgm
			
			args = [ ]
			
			args << "-T" << "svg" if renderer == :mscgen || GraphvizRenderers.include?(renderer.to_s)
			args << "-t" << "svg" if renderer == :shaape
			args << "-tsvg" if renderer == :plantuml
			
			if scale && !scale.eql?(1.0)
				args << "-s" << scale.to_s if renderer == :shaape
				args << "-s" << (scale * 72.0).to_s if GraphvizRenderers.include?(renderer.to_s)
			end
			
			args << "-charset" << encoding if encoding && renderer == :plantuml
			args << "-o" << "/dev/stdout" if renderer == :mscgen || renderer == :shaape
			args << "-p" if renderer == :plantuml
			args << "-" if renderer == :shaape
			
			args
		end
		private :renderer_arguments
		
		def renderer_arguments_tex renderer
			args = [ ]
			
			args << "--interaction=nonstopmode"
			args << "-output-format" << "dvi" if renderer == :pdftex || renderer == :pdflatex
			args << "--output-format=dvi" if renderer == :luatex || renderer == :lualatex
			args << "-no-pdf" if renderer == :xetex || renderer == :xelatex
			args << "-no-shell-escape" unless renderer == :luatex || renderer == :lualatex
			
			if renderer == :luatex || renderer == :lualatex
				args << "--no-shell-escape"
				args << "--nosocket"
				args << "--safer"
			end
			
			args
		end
		private :renderer_arguments_tex
		
		def renderer_arguments_dvisvgm
			args = [ ]
			
			args << "-b" << "min"
			args << "-j"
			args << "--no-fonts"
			args << "-s"
			
			args
		end
		private :renderer_arguments_dvisvgm
	end
	
	class SVG < Graph
		def svgtag
			@svgtag ||= filter_for_inline_svg svg_xml
		end
		alias_method :output, :svgtag
		
		def filter_for_inline_svg xml
			doc = Nokogiri::XML(xml, nil, encoding) { |config| config.nonet }
			
			doc.xpath(".//comment()").remove
			
			doc.xpath("./xmlns:svg", doc.namespaces).first.to_html
		end
		private :filter_for_inline_svg
	end
	
	class Img < Graph
		Defaults = Graph::Defaults.merge({
			:dirname => "/images/graphs",
			:format => "img",
			:name => "graphs-%{hash}.svg"
		}).freeze
		
		StringOptions = (%w[dirname format name] + Graph::StringOptions).freeze
		
		ValueOptions = (NumberOptions + StringOptions).freeze
		Options = (Flags + ValueOptions).freeze
		
		Formats = %[img object embed iframe url uri href]
		
		# This is included to satisfy:
		# https://github.com/jekyll/jekyll/blob/c4a2ac2c4bfc4952ac73f4f69722718c2ec0c744/lib/jekyll/site.rb#L351
		# In reality Img has no meaningful path
		attr_reader :relative_path, :path
		
		def dir
			@options[:dirname] % { :hash => hash, :slug => slug }
		end
		
		def name
			@options[:name] % { :hash => hash, :slug => slug }
		end
		
		def format
			raise ArgumentError.new "invalid format value" unless Formats.include? @options[:format].to_s.downcase
			
			@options[:format].to_s.downcase.to_sym
		end
		
		def title
			@title ||= begin
				doc = Nokogiri::XML(svg_xml, nil, encoding) { |config| config.nonet }
				
				doc.remove_namespaces!
				
				title = doc.xpath(%(.//g[@class="graph"][1]/title[1]/text()))
				
				return case renderer
					when :mscgen then "Mscgen"
					when :plantuml then "PlantUML"
					when :shaape then "Shaape"
					when *GraphvizRenderers.map(&:to_s) then "Graphviz"
					when *TeXRenderers.map(&:to_s) then "TeX"
					else hash
					end if title.empty? 
				
				title.first.to_s
			end
		end
		
		def slug
			Jekyll::Utils.slugify title
		end
		
		def relative_destination
			File.join *[dir, name].compact
		end
		alias_method :url, :relative_destination
		
		def destination dest
			File.join *[dest, relative_destination].compact
		end
		
		def output_ext
			File.extname relative_destination
		end
		
		def imgtag
			%(<img src="#{url}" alt="#{title}" title="#{title}" />)
		end
		
		def objecttag
			%(<object data="#{url}" type="image/svg+xml"><a href="#{url}">#{title}</a></object>)
		end
		
		def embedtag
			%(<embed src="#{url}" type="image/svg+xml" />)
		end
		
		def iframetag
			%(<iframe src="#{url}" sandbox="allow-scripts"></iframe>)
		end
		
		def output
			case format
			when :img then imgtag
			when :object then objecttag
			when :embed then embedtag
			when :iframe then iframetag
			when :url, :uri, :href then url
			else raise ArgumentError.new "invalid format value"
			end
		end
		
		def write?
			true
		end
		
		def write dest
			dest_path = destination dest
			
			return false if File.exist?(dest_path) && dest_path.include?(hash)
			
			FileUtils.mkdir_p File.dirname dest_path
			
			svg = svg_xml
			File.write dest_path, svg if svg && !svg.empty?
			
			File.exist? dest_path
		end
		
		def to_s
			source || ""
		end
		
		def to_liquid
			{
				"url" => url,
				
				"content" => source,
				"output" => output,
				
				"graphs" => Jekyll::Utils.stringify_hash_keys(@options)
			}
		end
	end
	
	class TagSVG < SVG
		def initialize site, content, options = { }
			@content = content
			
			super site, options
		end
		
		def source
			source = @content.dup
			
			source.gsub! '\n', "\n"
			source.gsub! /^$\n/, ""
			source.gsub! /^\[\"\n/, ""
			source.gsub! /\"\]$/, ""
			
			source
		end
		undef_method :source=
	end
	
	class TagImg < Img
		def initialize site, content, options = { }
			@content = content
			
			super site, options
		end
		
		def source
			source = @content.dup
			
			source.gsub! '\n', "\n"
			source.gsub! /^$\n/, ""
			source.gsub! /^\[\"\n/, ""
			source.gsub! /\"\]$/, ""
			
			source
		end
		undef_method :source=
	end
end

module Jekyll
	class Tags::JGraphsBlock < Liquid::Block
		def initialize tag_name, markup, tokens
			super
			
			@attributes = parse_attributes markup
			
			if tag_name == "tex"
				@attributes[:renderer] = :tex unless JGraphs::Graph::TeXRenderers.include? @attributes[:renderer]
			elsif tag_name == "graphviz"
				@attributes[:renderer] = :dot unless JGraphs::Graph::GraphvizRenderers.include? @attributes[:renderer]
			elsif JGraphs::Graph::Renderers.include? tag_name
				@attributes[:renderer] = tag_name.to_sym
			end
		end
		
		def render context
			site = context.registers[:site]
			
			format = @attributes[:format]
			format ||= site.config["jgraphs"]["format"] unless site.config["jgraphs"].nil?
			
			if format && JGraphs::TagImg::Formats.include?(format.downcase)
				# Unforunately this will not be included in the site_payload that
				# is avaliable to liquid because site_payload is evaluated long
				# before this graph is added
				site.static_files << graph = JGraphs::TagImg.new(site, super, @attributes)
			else
				graph = JGraphs::TagSVG.new site, super, @attributes
			end
			
			graph.output
		end
		
		def parse_attributes markup
			# boolean key|no-key options
			attributes = Hash[markup.scan(/(?<=\s|^)(no-)?(\w+)(?=\s|$)/i).map { |falsey, key| [key.to_sym, !falsey] }.compact]
			
			# key:value options
			attributes.merge! Hash[markup.scan(Liquid::TagAttributes).map { |key, value| [key.to_sym, value] }.compact]
			
			attributes
		end
		private :parse_attributes
	end
	
	class Tags::JGraphsTag < Liquid::Tag
		VARIABLE_SYNTAX = /(?<variable>[^{]*\{\{\s*(?<name>[\w\-\.]+)\s*(\|.*)?\}\}[^\s}]*)(?<params>.*)/
		
		def initialize tag_name, markup, tokens
			super
			
			if matched = markup.strip.match(VARIABLE_SYNTAX)
				@file = matched["variable"].strip
				params = matched["params"].strip
			else
				@file, params = markup.strip.split(" ", 2);
			end
			
			@attributes = parse_attributes params
			
			tag_base_name = tag_name[0..-6]
			
			if tag_base_name == "tex"
				@attributes[:renderer] = :tex unless JGraphs::Graph::TeXRenderers.include? @attributes[:renderer]
			elsif tag_base_name == "graphviz"
				@attributes[:renderer] = :dot unless JGraphs::Graph::GraphvizRenderers.include? @attributes[:renderer]
			elsif JGraphs::Graph::Renderers.include? tag_base_name
				@attributes[:renderer] = tag_base_name.to_sym
			end
		end
		
		def render context
			site = context.registers[:site]
			
			format = @attributes[:format]
			format ||= site.config["jgraphs"]["format"] unless site.config["jgraphs"].nil?
			
			if format && JGraphs::Img::Formats.include?(format.downcase)
				# Unforunately this will not be included in the site_payload that
				# is avaliable to liquid because site_payload is evaluated long
				# before this graph is added
				site.static_files << graph = JGraphs::Img.new(site, @attributes)
			else
				graph = JGraphs::SVG.new site, @attributes
			end
			
			graph.file = render_variable(context) || @file
			graph.source = File.read File.join(site.source, graph.file), site.file_read_opts
			
			graph.output
		end
		
		def render_variable context
			Liquid::Template.parse(@file).render! context if @file.match VARIABLE_SYNTAX
		end
		private :render_variable
		
		def parse_attributes markup
			# boolean key|no-key options
			attributes = Hash[markup.scan(/(?<=\s|^)(no-)?(\w+)(?=\s|$)/i).map { |falsey, key| [key.to_sym, !falsey] }.compact]
			
			# key:value options
			attributes.merge! Hash[markup.scan(Liquid::TagAttributes).map { |key, value| [key.to_sym, value] }.compact]
			
			attributes
		end
		private :parse_attributes
	end
end

Liquid::Template.register_tag "graphviz", Jekyll::Tags::JGraphsBlock
Liquid::Template.register_tag "graphviz_file", Jekyll::Tags::JGraphsTag
JGraphs::Graph::Renderers.each do |renderer|
	Liquid::Template.register_tag renderer.to_s, Jekyll::Tags::JGraphsBlock
	Liquid::Template.register_tag "#{renderer}_file", Jekyll::Tags::JGraphsTag
end

# Kramdown codeblock support
begin
	require "kramdown"
	
	class Jekyll::Site
		# Markdown support is added with a converter, by adding site here
		# we guarantee it will be available to Kramdown::Converter::Html
		alias_method :super_jgraphs_converters, :converters
		def converters
			@jgraphs_has_patched ||= begin
				config["kramdown"] ||= { }
				config["kramdown"][:__jgraphs_site__] = self
				
				true
			end
			
			super_jgraphs_converters
		end
	end
	
	class Kramdown::Converter::Html
		alias_method :super_jgraphs_convert_codeblock, :convert_codeblock
		def convert_codeblock el, indent
			attr = el.attr.dup
			klass = attr["class"]
			
			renderer = JGraphs::Graph::Renderers.select {|renderer| attr.delete renderer }.first
			
			return super_jgraphs_convert_codeblock el, indent unless renderer || attr.delete("graphviz") || attr.delete("jgraphs")
			
			site = @options[:__jgraphs_site__]
			
			arguments = { }
			
			unless klass.to_s.empty?
				# Class attribute boolean key|no-key options
				flags = Hash[klass.scan(/(?<=\s|^)(no-)?(\w+)(?=\s|$)/i).map { |falsey, key| [key.to_sym, !falsey] }.compact]
				flags.keep_if { |key, _| JGraphs::TagImg::Flags.include? key }
				flags.each_key { |key| klass.gsub! /(?:\s|^)(no-)?#{Regexp.escape key}(?:\s|$)/i, "" }
				arguments.replace flags
				
				attr.delete "class" if flags.length.nonzero? && klass.empty?
			end
			
			# IAL flags
			arguments.merge! Hash[JGraphs::TagImg::Flags.map do |key|
				[key.to_sym,
					case attr.delete key
					when /^(?:true|1|#{Regexp.escape key})$/i then true
					when /^(?:false|0)$/i then false
					else next
					end
				]
			end.compact]
			
			# IAL options
			arguments.merge! Hash[JGraphs::TagImg::ValueOptions.map { |key| [key.to_sym, attr.delete(key) || next] }.compact]
			
			arguments[:renderer] = renderer if renderer
			
			format = arguments[:format]
			format ||= site.config["jgraphs"]["format"] unless site.config["jgraphs"].nil?
			
			if format && JGraphs::TagImg::Formats.include?(format.downcase)
				# Unforunately this will not be included in the site_payload that
				# is avaliable to liquid because site_payload is evaluated long
				# before this graph is added
				site.static_files << graph = JGraphs::TagImg.new(site, el.value, arguments)
			else
				graph = JGraphs::TagSVG.new site, el.value, arguments
			end
			
			case graph.format
			when :img then
				attr["src"] = graph.url
				"#{" " * indent}<img#{html_attributes attr} />\n"
			when :object then
				attr["data"] = graph.url
				attr["type"] = "image/svg+xml"
				"#{" " * indent}<object#{html_attributes attr}></object>\n"
			when :embed then
				attr["src"] = graph.url
				attr["type"] = "image/svg+xml"
				"#{" " * indent}<embed#{html_attributes attr} />\n"
			when :iframe then
				attr["src"] = graph.url
				attr["sandbox"] ||= "allow-scripts"
				"#{" " * indent}<iframe#{html_attributes attr}></iframe>\n"
			else
				svg = graph.output
				svg.insert "<svg".length, html_attributes(attr)
				
				"#{" " * indent}#{svg}\n"
			end
		end
	end
rescue LoadError
end