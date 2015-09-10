#!/usr/bin/env ruby
require 'optparse'
require File.join(File.dirname(__FILE__), '..', 'importers', 'importer')
require 'dbi'
require 'yaml'

module TicketTemplate

	# Use to check the user's entries into the program for validity:
	class EntryValidator

		# Check for a valid Numeric Entry
		def checkNumericEntry(userInput, limit)
			
			validEntry = 0

			if userInput =~ /[1-9]+/

				userInput = userInput.to_i
				
				if userInput <= limit
					validEntry = userInput
				else
					validEntry = 0
					invalidReason = "Value is greater than expected limit." 
				end
			else
				validEntry = 0
				invalidReason = "Value is not a numerical value."
			end

			return validEntry
		end
		
		# Check for a valid Yes/No Entry
		def checkBinaryAnswer(userInput)

			validEntry = 0

			if userInput =~ /Y|N|YES|NO/i
				validEntry = 1

			end
			return validEntry
		end
	end
	
	# Client Parser to import ticket Outlines into a DB Table:
	class Import < Parser::TicketTemplateImport
	
		puts "Preparing to parse and import the selected outline file into a table:"
		
	end
	
	# Extracter to get a ticket template's lines from DB Table:
	class Configuration
		# class methods
		class << self
			# create or return global config instance
			def instance(path = Configuration.default_path)
				unless @instance
					@instance = self.new(path)
					@instance.load
				end
				@instance
			end

			def default_path
				File.expand_path(File.join(File.dirname(__FILE__), '..', 'importers','config', 'importers.yaml'))
			end
		end

		attr_reader :path

		def initialize(path)
			@path = path
		end

		# read and return contents of config file
		def read
			File.read(@path)
		end

		# load YAML content
		def load
			@config = YAML.load(self.read)
			self
		end

		# proxy missing methods to @config hash
		def method_missing(name, *args, &block)
			@config.send(name, *args, &block)
		end

		# helper functions

		def database_connection(db_alias)
			connection = @config['database']['connections'][db_alias.to_s]
			raise ConfigurationError, "Unknown database '#{db_alias}'." if connection.nil?
			connection
		end

		def database_service(db_alias)
			connection = database_connection(db_alias)
			connection['service']
		end

		def database_alias(service)
			@config['database']['connections'].each_key do |db_alias|
				return db_alias if @config['database']['connections'][db_alias].has_value?(service.to_s)
			end
			raise ConfigurationError, "Unknown database '#{service}'."
		end

		def database_password(db_alias, username)
			connection = database_connection(db_alias)
			password = connection['credentials'][username.to_s]
			raise ConfigurationError, "Unknown username '#{username}' for database '#{db_alias}'." if password.nil?
			password
		end
	end

	class TicketTemplateExtract

		@@connections = {}

		def oracle_connection(db_alias, username, config = @config)
			username = username.to_s
			password = config.database_password(db_alias, username)
			service = config.database_service(db_alias)

			@@connections["#{db_alias}-#{username}"] ||=
				DBI.connect("DBI:OCI8:#{service}", username, password)
		end


		def initialize(db = 'sentrys2', usrName = 'FREEDOM', tblName = 'TICKET_TEMPLATE')
			@config  = Configuration.instance
			db_alias = @config.database_alias(db)
			@oracle  = oracle_connection(db_alias, 'freedom', @config)
			@userName = usrName
			@tableName = tblName

		end

		def extract
		
			# Replace with the users input Ticket Type Table
			result = @oracle.prepare("SELECT LINE_TYPE, LINE FROM #{@userName}.#{@tableName}")
			
			result.execute		
			
			result.fetch do |row|
				#puts row.join(' ')
				rowList.push(row.join(' '))
			end
			
			result.finish
			
			return rowList
			
		end
	end
	
	# Create a class to generate various portions of a ticket 
	class TicketTemplate_Generate

		def initialize()
			
			puts "Enter your ticket number: "
			in_ticketNum = gets.chomp
			@ticketNum = in_ticketNum
			puts ""
			
			@ticketTypes = 
			{
				"sentrex" =>
				{
					"pharmacyshutdown" => 
					{
						clientID,
						contractID,
						termDate
					}
				}
			}
			
			@dirName = "ticket_" + @ticketNum
			@fileName = "T#" + @ticketNum + "_Template.txt"
			@path = "~/" + @dirName
			@enviro = {"P" => "PRODUCTION", "S" => "STAGING", "D" => "DEVELOPMENT", "I" => "IMPLEMENTATION"}
			@users = {"FR" => "FREEDOM", "APP_SPT" => "APPSUPPORT", "APP_USR" => "APPUSER"}
	
		end
		
		# Usage: Allow the user to generate a very basic ticket structure by    
		# supplying a number specifying the number of steps to include defaults to 5
		
		def setupDir()
			# Create a directory
			`mkdir #{@path}`
			`mkdir #{@path}/docs`
			`mkdir #{@path}/pics`
			`mkdir #{@path}/sql`
		end

		def moveTemplate()

			# Get current directory
			@pwd = `pwd`
			from = @pwd.gsub("\n", "") + "/" + @fileName
			to = `echo $HOME`.gsub("\n", "") + "/" + @dirName + "/docs"

			`mv "#{from}" "#{to}"`
		end

		def getUserTickets()
			# Run an SQL command to get the ticket's title from Table
			`sqlplus freedom@dev`

		end


		def newTemplate()
			# Create a blank ticket file
			@custTempFile = File.new("#{@fileName}", "w")
		end
		
		
		def generateTemplate(preLines)
			
			# Run extract method to get lines from database table instead
			# Run TicketTemplate_Extract()
			
			lineIndex = 0
			
			preLines.each do |line|
				
				if
					
					templateIndex += 1
					
					template[templateIndex] = Array.new()
					
				end
				
				# Add each formatted line to the template Array
				#@template.push( Object.const_get(@lineType[values[0]]).new(templateIndex, values[1], values[2], values[3], values[4], values[5] )
				
				# Add the line to the template substituting the # for the template Index and any QRS vsalues with the index of the array it is applied to.
				template[templateIndex].push(values[length(values)-1]).sub!("#", templateIndex.to_s)
			end
		end
	end

	# Main Function:
	class TTRunner
	
		def initialize
		
			@usrPathList = `echo $HOME`.gsub(/\W/, " ").split(" ")
			@usrDirHash = Hash.new()
			@usrPath = ""
			
		end
		
		def get_usrPath
			
			@usrPath = ""
			
			@usrPathList.each do |pathDir|
				@usrPath += "/"
				@usrPath += (pathDir.to_s)
			end
			
			puts "The user's current directory is #{@usrPath}"
			
			return @usrPath
			
		end
		
		def set_usrPath(usrDir)
			
			@usrPathList = @usrDirHash[usrDir].gsub(/\W/, " ").split(" ")
			
			self.get_usrPath
		end
		
		def add_usrPath(newDirName)
		
			@usrPathList.push(newDirName)
			
			self.get_usrPath
			
			# puts "Users current location: #{usrPath}"
			
		end
		
		def rm_usrPath(numLevels)
		
			@usrPathList.pop()
			
			self.get_usrPath
			
			# puts "Users current location: #{usrPath}"
			
		end
		
		def mkDir(newDirName)
			
			self.get_usrPath
			
			newDir = @usrPath + "/" + newDirName
			
			Dir.mkdir(newDir) unless File.exists?newDir
			
			@usrDirHash[newDirName] = newDir
			
		end
		
		# Create a directory for user to write templates to
		def MainDirSetup
			
			# Create a Hash of directoryName to paths for easy user navigation?
		
			ttDir = self.mkDir("ticketTemplateFiles")
			
			# Move to the ticketTemplateFiles directory:
			self.add_usrPath("ticketTemplateFiles")
			
			# Create the main tt Directories: outlines, templates, and codeLibrary
			
			templateDir = self.mkDir("templates")
			
			outlineDir = self.mkDir("outlines")
				
			codeLibDir = self.mkDir("codeLibrary")
			
			# Move to the templates directory:
			self.add_usrPath("templates")
			
			# Create dirs for folders under templates: extracts, generated
			
			extDir = self.mkDir("extracts")
			
			genDir = self.mkDir("generated")
			
			# Go up 1 level
			self.rm_usrPath(1)
			
		end
		
		
		def NewDirSetup(newUsrDir)
			
			# newUsrDir = usrPath + "/" + newUsrDirName
			
			Dir.mkdir(newUsrDir) unless File.exists?newUsrDir
			
		end
			
		# Display various lists to allow the user to select a value:
		def DisplayList(optionList)
			
			optionSelected = FALSE
			
			while !optionSelected
			
				puts "Please enter a menu option number: "
				puts ""
				
				optIndex = 1
				
				optionList.each do |option|
						puts optIndex.to_s + '. ' + option
						optIndex += 1
				end
		
				# Get user entry
				optionNum = gets.chomp
				
				# Check if user entry is valid
				if entryValid.checkNumericEntry(optionNum, optionList.length) != 0
					optionSelected = TRUE
					optionNum = optionNum.to_i
				else
					puts "INVALID ENTRY: Please enter a numeric menu value."
				end
				
			end
			
			return optionNum
			
		end

		def UI_Run
		
			optionList = 
			[
				"Search For and Generate a Template",
				"Import a Template"
			]
			
			# Allow user to select an option
			optionSelected = FALSE

			entryValid = EntryValidator.new()

			puts "This program will allow you to manage templates for various categories of tickets:"

			while !optionSelected
			
				puts "Please enter a menu option number: "
				puts ""
				
				optIndex = 1
				
				optionList.each do |option|
						puts optIndex.to_s + '. ' + option
						optIndex += 1
				end
		
				# Get user entry
				optionNum = gets.chomp
				
				# Check if user entry is valid
				if entryValid.checkNumericEntry(optionNum, 2) != 0
					optionSelected = TRUE
					optionNum = optionNum.to_i
				else
					puts "INVALID ENTRY: Please enter a numeric menu value."
				end
			end

			optionSelected = FALSE


			# Rewrite to use my directory/file listing code completed below for the parse/import process!!!
			if optionNum == 1
				
				puts "Loading the Template Library: "
				
				puts "Please select a product to generate a ticket template for: "
				
				# Set up the main directories for outline and template files in the users home directory if necessary:
				baseDir = MainDirSetup()
				# Find the product this outline is attributed to:
				self.set_usrPath("outlines")
				
				prodSelected = FALSE
					
				while !prodSelected
				
					puts "Please select the product attributed to your outline file to import:"
					
					prodDirList = %x(ls "#{@usrPath}").split("\n")
					
					prodIndex = 1
					
					prodDirList.each do |prodDir|
						puts prodIndex.to_s + '. ' + prodDir
						prodIndex += 1
					end
					
					usrProdNum = gets()
					
					# Check the users numeric entry for a Product Number:
					if entryValid.checkNumericEntry(usrProdNum, prodDirList.length) != 0
						
						# Get the name of the Product from an array:
						usrProdName = prodDirList[usrProdNum.to_i-1]
						
						prodSelected = TRUE
						
						puts "You have selected the Product: " + usrProdName
						
						self.add_usrPath(usrProdName)
					end
		
				end
				
				# Find the project this outline is attributed to:
				projSelected = FALSE
					
				while !projSelected
				
					puts "Please select the project attributed to the import file:"
					projDirList = %x(ls "#{@usrPath}").split("\n")
					projDirList.push("Add a new Project")
					
					projIndex = 1
					
					projDirList.each do |projDir|
						puts projIndex.to_s + '. ' + projDir
						projIndex += 1
					end
	
					usrProjNum = gets()
					
					# Check the users numeric entry for a Project Number:
					if entryValid.checkNumericEntry(usrProjNum, projDirList.length) != 0
						
						# Get the name of the Project from an array:
						usrProjName = projDirList[usrProjNum.to_i-1]
						
						projSelected = TRUE
						
						puts "You have selected the Project: " + usrProjName
						
						self.add_usrPath(usrProjName)
					end
				end
				
				
				# Query the database to display ticket template names, but for now just use an array
				# templateTablesSQL = "SELECT TABLE_NAMES(*) FROM TICKET_TEMPLATE WHERE TABLE_NAME REGEXP_LIKE 'usrProdName_usrProjName';"
				# ticketTypes = run(templateTablesSQL).split("\n")


				
				# Run the extract process to get the ticket's template lines:
				extractLines = TicketTemplateExtract.new
				prelimTemplate = extractLines.extract
				
				# Run the ticket type's class constructor
				
				# usrGenAct = "#{options[:default][:sentryProds][usrProdNum-1]}_#{ticketTypes[usrTTNum-1]}"
				
				# usrTemp = Object.class_eval( usrGenAct.to_s ).new()
				
				# Read in the prelimiary template into the generate process
				# Pass in the product and project to get hash of parameters? 
				usrTemplate = TicketTemplate_Generate.new()
				
				# generate the template by getting user input anfd replacing step nuumbers and other important attributes.
				usrTemplate.generateTemplate(prelimTemplate)

			elsif optionNum == 2

				puts "Importing a Ticket Template: "
				puts ""
				
				# Set up the main directories for outline and template files in the users home directory if necessary:
				baseDir = MainDirSetup()
				
				# Find the product this outline is attributed to:
				self.set_usrPath("outlines")
				
				prodSelected = FALSE
					
				while !prodSelected
				
					puts "Please select the product attributed to your outline file to import:"
					
					prodDirList = %x(ls "#{@usrPath}").split("\n")
					prodDirList.push("Add a new Product")
					
					prodIndex = 1
					
					prodDirList.each do |prodDir|
						puts prodIndex.to_s + '. ' + prodDir
						prodIndex += 1
					end
					
					usrProdNum = gets()
					
					# Check the users numeric entry for a Product Number:
					if entryValid.checkNumericEntry(usrProdNum, prodDirList.length) != 0
						
						# Get the name of the Product from an array:
						usrProdName = prodDirList[usrProdNum.to_i-1]
												
						# User wants to add a new prod directory:
						if usrProdNum.to_i == prodDirList.length
							puts "Please enter a name for the new product (Leave BLANK to cancel): "
							newProdName = gets.chomp!
							
							if newProdName == ""
								puts "Cancelling new Product addition:"
								prodSelected = FALSE
								
							else
								puts "Creating new product directory for " + newProdName.to_s
								
								# Create the new product Directory
								newProdDir = self.mkDir(newProdName)
								
								# Move to the new Product Directory
								self.add_usrPath(newProdName)
								
								# End prod selection loop
								prodSelected = TRUE
								
								puts "You have selected the Product: " + newProdName
							end
						
						else
							prodSelected = TRUE
							
							puts "You have selected the Product: " + usrProdName
							
							self.add_usrPath(usrProdName)
						end
		
					end
				
				end
				
				# Find the project this outline is attributed to:
				projSelected = FALSE
					
				while !projSelected
				
					puts "Please select the project attributed to the import file:"
					projDirList = %x(ls "#{@usrPath}").split("\n")
					projDirList.push("Add a new Project")
					
					projIndex = 1
					
					projDirList.each do |projDir|
						puts projIndex.to_s + '. ' + projDir
						projIndex += 1
					end
	
					usrProjNum = gets()
					
					# Check the users numeric entry for a Project Number:
					if entryValid.checkNumericEntry(usrProjNum, projDirList.length) != 0
						
						# Get the name of the Project from an array:
						usrProjName = projDirList[usrProjNum.to_i-1]
												
						# User wants to add a new proj directory:
						if usrProjNum.to_i == projDirList.length
							puts "Please enter a name for the new product (Leave BLANK to cancel): "
							newProjName = gets.chomp!
							
							if newProjName == ""
								puts "Cancelling new Product addition."
								projSelected = FALSE
								
							else
								puts "Creating new product directory for " + newProjName.to_s
								
								# Create the new project Directory
								newProdDir = self.mkDir(newProjName)
								
								# Move to the new Project Directory
								self.add_usrPath(newProjName)
								
								# End project selection loop
								projSelected = TRUE
					
								puts "You have selected the Project: " + newProjName
							end
						
						else
							projSelected = TRUE
							
							puts "You have selected the Project: " + usrProjName
							
							self.add_usrPath(usrProjName)
						end
					end
				end
				
				# Find the outline to import:
				
				outlineSelected = FALSE
					
				while !outlineSelected 
					
					puts "Please copy your outline file to the directory: " + @usrPath
					puts " "
					puts "Please select the outline file to import from the list below: "
					
					outlineFileList = %x(ls "#{@usrPath}").split("\n")
					outlineFileList.push("Reload file listing")
					
					outlineIndex = 1
					
					# Display all outline files with an index number for user to select:
					outlineFileList.each do |outlineFile|
						puts outlineIndex.to_s + '. ' + outlineFile
						outlineIndex += 1
					end
					
					# outlineDir = TTDirSetup(usrProd, usrProj)
					
					usrOutlineNum = gets()
					
					# Check the users numeric entry for an 	outline file:
					if entryValid.checkNumericEntry(usrOutlineNum, outlineFileList.length) != 0
						
						# Get the name of the Project from an array:
						usrOutlineFileName = outlineFileList[(usrOutlineNum.to_i)-1]
												
						# IF User wants to RELOAD the files listing:
						if usrProjNum.to_i == projDirList.length
							puts "Reload file listing: "
							newProjName = gets.chomp!
							
							outlineSelected = FALSE
								
						else
							puts "You have selected to import the outline file: " + usrOutlineFileName.to_s
							
							# End project selection loop
							outlineSelected = TRUE
							
						end
					# Invalid numeric entry entered for a file by user
					else
					
						puts "ERROR >> Please enter a numeric value corresponding to a file to import: "
						
					end		
				
				end
				
				puts "Preparing to parse and import the file: #{usrOutlineFileName} into the Database:"
				
				# The options Hash has child hashes as default values.
				# The child hashes have respective values from the :default hash as defaults.  
				# Each child hash is for a specific project type: shutdown, orphan drug, dispense fee edit, etc ...
				# For example:
				#
				#   options[:default][:setting] = 'foo'
				#   options[:shutdown][:setting] # => 'foo'
				#   options[:shutdown][:setting] = 'bar'
				#   options[:shutdown][:setting] # => 'bar'
				#   options[:default][:setting] # => 'foo'
				#
				options = Hash.new do |options_hash, options_key| 
					options_hash[options_key] = Hash.new do |hash, key|
						# If any of the autocreated child hashes don't have a key, try to find
						# it in the sibling :default hash.
						options_hash[:default][key]
					end
				end

				# The default hash should be a regular Hash.  
				# It shouldn't look elsewhere for values.
				options[:default] = 
				{
					:driver => "Output::Driver::Oracle",
					:output => ".",
					:json_output_path => nil,
					:database => :dev,
					:color => false,
					:check => false,
					:import_ehr => true,
					:historical => false,
					:sentryProds => ["Sentinel", "Sentrex", "DataNext","SentryCore"]
				}
			
			# Handle user options: Dont need?
			'''
			OptionParser.new do |opts|
				context = :default

				# opts.banner = "Usage: #{$0} [options] Parser::Class input_file.txt"

				opts.separator ""
				opts.separator "Options:"

				opts.on("--host HOST", "Connect to host.") { |v|
					options[context][:host] = v
				}
				opts.on("--port PORT", "Connect to port.") { |v|
					options[context][:port] = v
				}
				opts.on("-D", "--database DATABASE", "Import to database. [default: #{options[:default][:database]}]") { |d|
					options[context][:database] = d.to_sym
				}
				opts.on("-z", "--compress", "Compress using gzip.") { |v|
					options[context][:compress] = true
				}
				opts.on("--collection COLLECTION", "Import to collection.") { |v|
					options[context][:collection] = v
				}
				opts.on("--drop-collection", "Drop the destination mongo collection first.") { |v|
					options[context][:drop_collection] = true
				}
				opts.on("-d", "--driver CLASSNAME", "Output driver. [default: #{options[:default][:driver]}]") { |d|
					context = d
					options[context][:driver] = d
				}
				opts.on("-o", "--output DIR", "Output directory. [default: #{options[:default][:output]}]") { |o|
					options[context][:output] = o
				}
				opts.on("-j", "--json-output DIR", "JSON output directory. [default: #{options[:default][:json_output_path]}]") { |o|
					options[context][:json_output_path] = o
				}
				opts.on("-P", "--prefix PREFIX", "Output filename prefix. [default: filename.db.]") { |p|
					options[context][:prefix] = p
				}
				opts.on("-t", "--tablecheck", "Create non-existant tables/sequences.") { |p|
					options[context][:check] = true
				}
				opts.on("-c", "--color", "Output with color.") { |v|
					options[context][:color] = true
				}
				opts.on("--clear", "Clear any existing output files") { |v|
					options[context][:clear] = true
				}
				opts.on("-h", "--help", "Show this message.") {
					puts opts
					exit
				}

				opts.separator ""
				opts.separator "EHR Options:"
				opts.on("-e", "--no-ehr", "Exclude importing EHR tables.") { |v|
					options[context][:import_ehr] = false
				}

			end.parse!
			'''
			
				# Use the import parser to parse outline files for import into database
				options[:default][:parser] = "TicketTemplate::Import"
				# Specify location of the outline file to parse and import
				options[:default][:input] = "#{@usrPath}/#{usrOutlineFileName}"
				
				# specify location to print ou"qt genertaed user template to:
				self.set_usrPath("extracts")
				
				newExtDir = self.mkDir(usrOutlineFileName.split(".")[0])
				
				self.add_usrPath(usrOutlineFileName.split(".")[0])
				
				options[:default][:output] = "#{@usrPath}"
				
				outputs = []
				
				# Create the outputs hash
				options.each do |key, hash|
					next if key == :default
					outputs << hash
				end
				
				outputs << options[:default] if outputs.empty?
				
				import = Object.class_eval(options[:default][:parser]).new(
				:imported_from => File.basename(options[:default][:input]),
				:input => [File.open(options[:default][:input], 'rb')],
				:json_output_path => options[:default][:json_output_path],
				:output => outputs.collect{|output|
					# The default prefix depends on other settings.  So we calculate one, if needed.
					output[:prefix] ||= File.basename(options[:default][:input]) + "." + output[:database].to_s + "."

					# Create and setup an output driver.
					Object.class_eval(output[:driver]).new(
						:destination => output[:output], 
						:tables => Object.class_eval(output[:parser])::Tables, 
						:color => output[:color], 
						:host => output[:host],
						:port => output[:port],
						:database => output[:database],
						:collection => output[:collection],
						:compress => output[:compress],											  
						:drop_collection => output[:drop_collection],
						:prefix => output[:prefix].gsub(/ /, '_'),
						:check => output[:check],
						:import_ehr => output[:import_ehr]
					)},
				:database => options[:default][:database]
			)
			
			# Run parse of the outline file to be imported:
			import.parse
			import.finalize
			
			# Create a table to import records to:
			
			# Run the import to place the parsed records into the table
			%x(bash "#{usrOutlineFileName}.#{output[:database]}.import.sh")
			 
			else
				puts "NULL"
			end
		end
	end
end

ttRun = TicketTemplate::TTRunner.new()

ttRun.UI_Run