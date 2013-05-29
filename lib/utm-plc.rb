#!/usr/bin/env ruby
# This file is part of UTM_plc.
# Copyright 2013 Jeff Welling (jeff.welling@gmail.com)
# 
# UTM_plc is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# UTM_plc is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with tget. If not, see <http://www.gnu.org/licenses/>.
# 
# Add the library from the source tree to the front of the load path.
# This allows tget to run without first installing the tget gem, which is
# important when testing multiple branches of development.
require 'pty'
require 'timeout'
require 'pp'

def _host; 					prompt('Which host?: ') end
def _port;					prompt('What port?: ')  end
def _lu_password;   prompt('What is the password for loginuser?: ', true) end
def _ru_password; 	prompt('What is the password for root?: ', true) end

$logging=false
$debugging=false

def disable_echo &block
	system('stty -echo')
	x=yield
	system('stty echo')
	#so that the next line doesn't start on the same line as the password prompt
	log
	x
end

def add_nl s
	#append a "\n" (newline) to a string if it doesn't already end with one.
	(s[/\\n$/].nil? ? s+"\n" : s)
end

def log string=String.new
	if $logging==true
		printf add_nl(string)
	end
	string
end

def debug string
	if $logging and $debugging
		printf add_nl(string) 
	end
	string
end

def login
	log "Logging in as loginuser..."
	$in.printf( _lu_password + "\n" )
	debug until_prompt( '/home/login >' )
end

def become_root
	log "Using su to become root..."
	$in.printf( "su\n" )
	debug until_prompt( 'Password:' )
	$in.printf( "#{_ru_password}\n" )
	debug until_prompt( '/home/login #' )
	log "Am now root."
end

def extract_profiles http
	debug "Extracting profiles from 'http'="
	profiles=http[/'profiles' => \[[^\]]*/].gsub( "'profiles' => \[",'' ).split(',').collect {|p| 
		p.strip.gsub(/^'/,'').gsub(/'$/,'') 
	}
	log "Found #{profiles.size} profiles:"
	profiles.each {|p|
	    log "               -- "+p
	}
end

def extract_exceptions http
	exceptions=http[/'exceptions' => \[[^\]]*/].gsub("'exceptions' => \[",'').split(',').collect {|l|
		l.gsub(/'/,'').strip 
	}
	exceptions.each {|e| log "               -- "+e }
end

def extract_cff_profiles raw_proxy_profile
	log "Found cff_profiles: "
	cff_p=raw_proxy_profile[/'cff_profiles' => \[[^\]]*/].gsub( "'cff_profiles' => \[",'' ).
		strip.gsub(',','').strip.gsub(/^'/,'').gsub(/'$/,'').strip.gsub(/^'/,'').gsub(/'$/,'')
	log "               -- "+cff_p
	cff_p
end

def extract_action raw_assignment
	raw_assignment[/'action' => '[^']*/].gsub(/'action' => '/,'').strip
end

def search_exceptions exceptions
	if exceptions.class!=Array
		raise ArgumentError "search_exceptions(exceptions): 'exceptions' must be an array but it's something else, possibly a cheeseburger..."
	elsif exceptions.empty?
		raise ArgumentError "search_exceptions(exceptions): 'exceptions' must be a non-empty array! What have you done?!?"
	end

	results={:exceptions=>[]}
	exceptions.each {|exception|
		debug raw_exception=get_object(exception)
		log "Checking exception: #{exception}"
		if _e_log_accessed?(raw_exception)
			results[:exceptions] << exception
		elsif _e_log_blocked?(raw_exception)
			results[:exceptions] << exception
		end
	}
	results
end

def search_profiles profiles
	if profiles.class!=Array
		raise ArgumentError "search_profiles(profiles): 'profiles' must be an array but it's something else, possibly a cheeseburger..."
	elsif profiles.empty?
		raise ArgumentError "search_profiles(profiles): 'profiles' must be a non-empty array! What have you done?!?"
	end
	results={:profiles=>[]}
	profiles.each {|profile|
		debug raw_proxy_profile=get_object(profile)
		log "Checking profile: #{get_name(raw_proxy_profile)}"
		debug raw_assignment=get_object( extract_cff_profiles(raw_proxy_profile) )
		log "Got the assignment for that profile..."
		action= get_action(raw_assignment)
		raw_action= get_object( extract_action(raw_assignment) )
		log "Got the action for that assignment..."

		if !_p_log_accessed?(raw_action) || !_p_log_blocked?(raw_action)
			log "Found an action that isn't logging everything: #{get_name(raw_action)}"
			results[:profiles] << raw_action
		end
	}
	results
end

def _p_log_accessed? action
	if action[/'log_access' => \d/].nil?
		raise ArgumentError "_p_log_accessed?(action): action doesn't contain a 'log_access' attribute?"
	end
	action[/'log_access' => \d/].gsub(/'log_access' => /,'')=='1'
end

def _p_log_blocked? action
	if action[/'log_blocked' => \d/].nil?
		raise ArgumentError "_p_log_blocked?(action): action doesn't contain a 'log_blocked' attribute?"
	end
	action[/'log_blocked' => \d/].gsub(/'log_blocked' => /,'')=='1'
end

def _e_log_accessed? raw_exception
	raw_exception[/'skiplist' => \[[^\]]*/].gsub("'skiplist' => \[",'').split(',').collect {|l|
		l.gsub(/'/,'').strip
	}.include? 'log_access'
end

def _e_log_blocked? raw_exception
	raw_exception[/'skiplist' => \[[^\]]*/].gsub("'skiplist' => \[",'').split(',').collect {|l|
		l.gsub(/'/,'').strip
	}.include? 'log_blocked'
end

def print_results results
	log "\n\nPrinting results:"
	results.each {|x,y|
		if x==:profiles
			y.each {|z|
				if !_p_log_accessed?(z)
					log "Please activate the 'Log Accessed Pages' option for the Web Filter Action named: #{get_name(z)}"
				end
				if !_p_log_blocked?(z)
					log "Please activate the 'Log Blocked Pages' option for the Web Filter Action named: #{get_name(z)}"
				end
			}
		elsif x==:exceptions
			y.each {|z|
				if _e_log_accessed?(get_object(z))
				 log "Please deactivate the option to skip logging of accessed pages for the Exception named: #{get_name(get_object(z))}"
				end
				if _e_log_blocked?(get_object(z))
				 log "Please deactivate the option to skip logging of blocked pages for the Exception named: #{get_name(get_object(z))}"
				end
			}
		end
	}
end

def get x, command='get'
	debug "Running: 'cc #{command} #{x}'..."
	$in.printf("cc #{command} #{x}\n")
	debug until_prompt(':/home/login #')
end

def print_raction raw_action
	log "Name: #{get_name(raw_action)}"
	log "Comment: #{get_comment(raw_action)}"
end

def get_name raw
	raw[/'name' => '[^']*/].gsub(/'name' => '/,'')
end

def get_comment raw
	raw[/'comment' => '[^']*/].gsub(/'comment' => '/,'')
end

def get_action raw_assignment
	raw_assignment[/'action' => '[^']*/].gsub(/'action' => '/,'').strip
end

def get_object x
	get x, 'get_object'
end

def fingerprint_prompt? string
	!string[/\(yes\/no\)\?/].nil?
end

def until_prompt( prompt )
	buffer= ""
	begin
		Timeout.timeout( 5 ) {
			loop do
				buffer << $out.getc.chr
				if fingerprint_prompt?(buffer)
					printf "SSH Fingerprint prompt detected.\nPlease SSH to this system at least once before using this program to verify the SSH fingerprint manually, then run this program again.\n\n"
					exit
				end
				break if buffer =~ Regexp.new(prompt)
			end
		}
		buffer
	rescue Timeout::Error => error
		printf "Error - Timed out waiting for \"#{prompt.gsub('"','\"') }\", printing stacktrace...\n "
    printf error.backtrace.join("\n") + "\n" 
		printf "Dumping buffer...\n"
		pp buffer
		printf "-------\n\n"
	end	
end

def prompt question, password=false
	printf question
	if password==true
		disable_echo {
			(s=gets.strip).empty? ? prompt(question) : s
		}
	else
		(s=gets.strip).empty? ? prompt(question) : s
	end
end

def run 
	PTY.spawn("ssh -p #{_port} loginuser@#{_host}") {|stdout,stdin,pid|
		old_out=$out; $out=stdout
		old_in=$in;   $in =stdin
		$logging=true

		debug( until_prompt('password:') )
		login
		become_root

		#Because the main Web Filter is treated as a profile, this
		#will operate on all Web Filters and proxy profiles.
	  results= search_profiles( extract_profiles( http=get('http') ) )
		results.merge!( search_exceptions( extract_exceptions( http ) ) )

		print_results( results )

		stdin.printf( "exit\n" )
		until_prompt( ":/home/login >" )
		stdin.printf( "exit\n" )

		$out=old_out
		$in=old_in
	}
	log 'Done'
end
