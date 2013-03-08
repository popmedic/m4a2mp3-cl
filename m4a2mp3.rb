#!/usr/local/bin/ruby

require 'iconv'
require 'mp3info'
require 'id3lib'

class M4a2Mp3
	def convertm4a2mp3 file
		title = ''
		artist = ''
		album = ''
		track = ''
		year = ''
		genre = ''
		img_data = false
		ic = Iconv.new('UTF-8//IGNORE', 'UTF-8')
		res = IO.popen(["faad", "-i", file, :err=>[:child, :out]]).read
		cres = ic.iconv(res + ' ')[0..-2]
		cres.lines do |line|
		#res.lines do |line|
		#puts "here"
			cline = ic.iconv(line + ' ')[0..-2]
			nvp = /(^.*)\:(.*$)/.match(cline)
			#nvp = /(^.*)\:(.*$)/.match(line)
			if(nvp != nil)
				n = nvp[1].strip
				v = nvp[2].strip
				if(n == 'title')
					title = v
				elsif(n == 'artist')
					artist = v
				elsif(n == 'album')
					album = v
				elsif(n == 'track')
					track = v
				elsif(n == 'date')
					year = v
				elsif(n == 'genre')
					genre = v
				end
			end
		end
		puts "\n File to convert:%s\n------------------\n Info\n-----\n  title: %s\n artist: %s\n  album: %s\n  track: %s\n   year: %s\n  genre: %s" % 
					[file, title, artist, album, track, year, genre]
		nfile = file.gsub(/\.m4a/, '.mp3')
		cmd = "mp4art --extract \"%s\"" % [file]
		`#{cmd}`
		afile = file.gsub(/\.m4a$/, ".art[0].jpg")
		if(!File.exists? afile)
			afile = file.gsub(/\.m4a$/, ".art[0].png")
		end
		if(!File.exists? afile)
			afile = file.gsub(/\.m4a$/, ".art[0].bmp")
		end
		if(File.exists? afile)
			puts " Exported image file: %s\n---------------------" % [afile]
			img_data = File.open(afile).read
			File.unlink(afile)
		end
		if(File.exists? nfile)
			puts "\n File exists: %s\n-----------------" % [nfile]
		else
			puts "\n Create file: %s\n-------------" % nfile
			cmd = "faad -o - \"%s\" | lame -h -b 192 - \"%s\"" % [file, nfile]
			puts cmd
			`#{cmd}`
		end
		#try_id3lib = false
		try_id3lib = true		
		if(File.exists? nfile)
			puts "\n Setting Info...\n----------------"
			if(!try_id3lib)
				Mp3Info.open nfile do |mp3|
					mp3.tag.title = title
					mp3.tag.artist = artist
					mp3.tag.album = album
					mp3.tag.tracknum = track.to_i
					mp3.tag.year = year
					mp3.tag.genre_s = genre
					if(img_data != false)
						begin
							mp3.tag2.add_picture(img_data)
						rescue => e
							puts "FAILED TO ATTACH PICTURE: %s" % e
							puts "Trying ID3lin"
							try_id3lib = true
						end
					end
				end
			end
			if(try_id3lib)
				tag = ID3Lib::Tag.new(nfile)
				tag.title = title
				tag.artist = artist
				tag.album = album
				tag.track = track
				tag.year = year	
				tag.genre = genre			
				cover = {
									:id          => :APIC,
									:mimetype    => 'image/jpeg',
									:picturetype => 3,
									:description => '.jpg',
									:textenc     => 0,
									:data        => img_data
								}
				tag << cover
				tag.update!
			end
		else
			puts "\n UNABLE TO CREATE MP3!!!\n------------------------"
			puts file
			return
		end
		puts "\n fin\n----"
	end
	
	def dirwalk dir
		Dir.foreach(dir) do |file|
			if(file[0] != '.')
				path = "%s/%s" % [dir, file]
				if(File.directory? path)
					dirwalk path
				elsif(File.extname(path) == ".m4a")
					convertm4a2mp3 path
				end
			end
		end
	end
	
	def run(dir=nil)
		if(dir == nil)
			dir = Dir.pwd
		end
		dirwalk dir
	end
end

app = M4a2Mp3.new()
fin = Dir.pwd
if(ARGV.length > 0)
	p = File.absolute_path(ARGV[0])
	if(File.directory? (p))
		app.run(p)
	elsif(File.exists? (p))
		app.convertm4a2mp3 p
	else
		puts "usage:\n m4a2mp3 <dir/filename>\n   example:\n     m4a2mp3 file.m4a\n     m4a2mp3 Guns\\ n\\ Roses/Lies\n     m4a2mp3"
	end
else
	app.run(Dir.pwd)
end
