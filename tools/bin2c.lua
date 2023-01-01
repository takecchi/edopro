-------------------------------------------------------------------------------
-- Name:		bin2c.lua
-- Purpose:	 Converts files into const unsigned char* C strings
-- Author:	  John Labenski
-- Created:	 2005
-- Copyright:   (c) 2005 John Labenski
-- Licence:	 wxWidgets licence
-------------------------------------------------------------------------------
-- This program converts a file into a "const unsigned char" buffer and a
--   size_t length for use in a C/C++ program. It requires lua >= 5.1 to run.
--
-- It outputs to the console so no files are modified, use pipes to redirect
--   or -o command line option to write to a specified file.
--
-- See "Usage()" function for usage or just run this with no parameters.
--
-- The program has two modes, binary and text.
--   In text mode; each line of the char buffer is each line in the input file.
--	  This will minimize the diffs for small changes in files put into CVS.
--   In binary mode (default), the file is dumped 80 cols wide as is.
-------------------------------------------------------------------------------


-- Write the contents of the table fileData (indexes 1.. are line numbers)
--  to the filename, but only write to the file if FileDataIsTableData returns
--  false. If overwrite_always is true then always overwrite the file.
--  returns true if the file was overwritten
local function WriteTableToFile(filename, fileData)
	assert(filename and fileData, "Invalid filename or fileData in WriteTableToFile")

	print("bin2c.lua - Updating file : '"..filename.."'")

	local outfile = io.open(filename, "w+")
	if not outfile then
		print("Unable to open file for writing '"..filename.."'.")
		return false
	end

	for n = 1, #fileData do
		outfile:write(fileData[n])
	end

	outfile:flush()
	outfile:close()
	return true
end

-- Read a file as binary data, returning the data as a string.
local function ReadBinaryFile(fileName)
	local file = assert(io.open(fileName, "rb"),
						"Invalid input file : '"..tostring(fileName).."'\n")
	local fileData = file:read("*all")
	io.close(file)
	return fileData
end

local function GetFilename(path)   
    return path:match("([^/\\]+)$")
end

-- Create the output header and prepend to the outTable
local function CreateHeader(stringName, fileName, fileSize, outTable)
	local headerTable = {}

	table.insert(headerTable, "/* Generated by bin2c.lua and should be compiled with your program.  */\n")

	table.insert(headerTable, "/* Access with :                                                     */\n")
	table.insert(headerTable, "/*   extern const size_t stringname_len; (excludes terminating NULL) */\n")
	table.insert(headerTable, "/*   extern const unsigned char stringname[];                        */\n\n")

	table.insert(headerTable, "#include <stdio.h>   /* for size_t */\n\n")

	table.insert(headerTable, string.format("/* Original filename: '%s' */\n", GetFilename(fileName)))

	table.insert(headerTable, string.format("extern const size_t %s_len;\n", stringName)) -- force linkage
	table.insert(headerTable, string.format("extern const unsigned char %s[];\n\n", stringName))

	table.insert(headerTable, string.format("const size_t %s_len = %d;\n", stringName, fileSize))
	table.insert(headerTable, string.format("const unsigned char %s[%d] = {\n", stringName, fileSize+1))

	-- prepend the header to the outTable in reverse order
	for n = #headerTable, 1, -1 do
		table.insert(outTable, 1, headerTable[n])
	end

	return outTable
end

-- Dump the binary data 20 bytes at a time so it's 80 chars wide
local function CreateBinaryData(fileData, outTable)
	local count = 0
	local len = 0
	local str = ""
	for n = 1, string.len(fileData) do
		str = str..string.format("%3u,", string.byte(fileData, n))
		len = len + 1
		count = count + 1
		if (count == 20) then
			table.insert(outTable, str.."\n")
			str = ""
			count = 0
		end
	end

	table.insert(outTable, str.."\n  0 };\n\n")
	return outTable, len
end

-- The main() program to run
return function(input,output)
	local stringName  = "bundled_font"

	local fileData = ReadBinaryFile(input)
	local outTable = {}
	local len = 0

	outTable, len = CreateBinaryData(fileData, outTable)

	outTable = CreateHeader(stringName, input, len, outTable)
	WriteTableToFile(output, outTable)

end
