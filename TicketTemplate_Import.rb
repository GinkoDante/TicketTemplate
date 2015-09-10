class Parser::TicketTemplateImport < Parser::Csv

	def settings
		super
		@feed_id = nil
		@delimiter = "\t"
		@headers = []
		@@stats = 
		{
			"IP" => "IN PROGRESS", 
			"D" => "DONE", 
			"B" => "BLOCKED", 
			"W" => "WAITING", 
			"PR" => "IN PEER REVIEW", 
			"C" => "CANCELLED",
			"R" => "RESOLVED",
			"AR" => "IN ARCHITECT REVIEW",
			"O" => "OPEN"
		}
		@@formats =
		{
			"I" => "*",
			"B" => "**",
			"CL" => "`",
			"CB" => "~~~"
		}
		@whsp = String.new
	end

	# Table names do not matter as the LineType defines how to construct the template line by line
	output_table :"freedom.ticket_template" do |t|
		t.string :line_type, :size => 10
		t.string :param1, :size => 300
		t.string :param2, :size => 100
		t.string :param3, :size => 100
		t.string :param4, :size => 100
		t.string :param5, :size => 100
		t.string :line, :size => 700
	end
	
	def each_row

		case @row[:line_type]
		
			when "MS"
				prfx = "#. "
				ptfx = ". **-- #{@@stats[@row[:param2]]}: #{@row[:param3]}."
				@row[:line] = "#{prfx}#{@row[:param1]}#{ptfx}"
				
			when "QRS"
				prfx = "* "
				ptfx = ": [^#]"
				@row[:line] = "#{prfx}#{@row[:param1]}#{ptfx}"
				
			when "HDR"
				prfx = "#{@@formats[@row[:param2]]}"
				ptfx = "#{@@formats[@row[:param2]]}"
				@row[:line] = "#{prfx}#{@row[:param1]}#{ptfx}"
				
			when "SCT"
				prfx = "---\n#{@@formats[@row[:param2]]}"
				ptfx = ":#{@@formats[@row[:param2]]}"
				@row[:line] = "#{prfx}#{@row[:param1]}#{ptfx}"
				
			when "MDCN"
				prfx = "#. "
				
				if @row[:param2].to_i > 2
					ptfx = ". **-- #{@@dcnType["MD"]}: #{@row[:param3]}."
				else
					ptfx = ". **-- #{@@dcnType["BD"]}: #{@row[:param3]}."
				end
				
				@row[:line] = "#{prfx}#{@row[:param1]}#{ptfx}"
				
			when "LRS"
				prfx = @whsp + "* "
				ptfx = ":\n[#{@row[:param3]}](#{@row[:param4]})"
				@row[:line] = "#{prfx}#{@row[:param1]}#{ptfx}"
				
			when "SDCN"
			
				prfx = @whsp + "*" + " [#{@row[:param3]}]: "
				
				if @row[:param2].to_i > 0
					if @row[:param2].to_i > 2
						ptfx = ": #{@@dcnType["MD"]}"
					else
						ptfx = ": #{@@dcnType["BD"]}"
					end
				else
					ptfx = "."
				end
				
				@row[:line] = "#{prfx}#{@row[:param1]}#{ptfx}"
				
			when "NS"
			
				prfx = @whsp + "*"
				ptfx = ": "
				@row[:line] = "#{prfx}#{@row[:param1]}#{ptfx}"
		end
		
	end
end
