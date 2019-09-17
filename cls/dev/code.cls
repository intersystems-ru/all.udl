/// Export different types of modules in different subfolders in UDL (plain) format
/// test.dfi -> /dfi/test.dfi
/// testpkg.test.cls -> /cls/testpkg/test.cls
Class dev.code [ Abstract ]
{

Parameter version = "1.1.0.4";

/// export all available code
ClassMethod export(mask = "", generated = 0, system = 0, percent = 0, mapped = 0, dfi = 0)
{
	#define export(%code, %file) s sc = $system.OBJ.ExportUDL(%code, %file,"/diffexport") ##continue
								 w:sc "Ok" d:'sc $system.OBJ.DisplayError(sc)

	#define isGenerated(%code) ##class(%RoutineMgr).IsGenerated( %code )
	#define isPercented(%code) ("%" = $e(%code))
	#define isMapped(%code) ##class(%RoutineMgr).IsMapped( %code )
	#define log w !, code, " -> ", $piece(filename,..workdir(),2), " "
						
	w "#; Exporting to ", ..workdir(),!
	#; classes
	s rs = ##class(%ResultSet).%New("%Dictionary.ClassDefinition:Summary")
	if rs.Execute() {

		while rs.%Next(){

			s code = rs.Name _ ".cls", isSystem = rs.System
			if ( 'system && isSystem ) continue
			if ( 'generated && $$$isGenerated( code ) ) continue
			if ( 'percent && $$$isPercented( code ) ) continue
			if ( 'mapped && $$$isMapped( code ) ) continue
			if ( '..checkMasks( code, mask ) ) continue
			
			s filename = ..filename( code )
			do ..mkdir( filename )
			$$$log
			$$$export( code, filename )

		} s rs=""
	}

	#; routines
	s rs = ##class(%ResultSet).%New("%Routine:RoutineList")
	if rs.Execute() {

    	while rs.%Next() {

	 		s code = rs.Name
	 		w code,!
	 		if ( 'generated && $$$isGenerated( code ) ) continue
	 		if ( 'percent && $$$isPercented( code ) ) continue
			if ( 'mapped && $$$isMapped( code ) ) continue
			if ( '..checkMasks( code, mask ) ) continue
			
			s filename = ..filename( code )
			do ..mkdir( filename )
			$$$log
			$$$export( code, filename )

	    } s rs=""
	}


	#; dfi
	do ..fixDashIntoName()
	#define export(%code,%file) s sc = ##class(%DeepSee.UserLibrary.Utils).%Export( %code, %file, 0 ) 
	
	s sql = "Select id, fullName as Name, documentName From %DeepSee_UserLibrary.FolderItem"
    s rs = ##class(%SQL.Statement).%ExecDirect( .stm, sql )
    while rs.%Next() {
		set code = rs.Name
		set filename = ..filename( code_".dfi" )
		set documentName = rs.documentName
		
		if ($L(code,"$TRASH")>1) continue
		
		if ( 'generated && $$$isGenerated( code ) ) continue
	 	if ( 'percent && $$$isPercented( code ) ) continue
		if ( 'mapped && $$$isMapped( code ) ) continue
		if ( '..checkMasks(documentName, mask) ) continue
		
		do ..mkdir( filename )
		
		if dfi{
			$$$log
			$$$export( code, filename)
		}
		elseif ('dfi){
			set documentName = $replace(documentName,"/","-")
			set filename = $extract(filename,1,*-4)
			do ..fixXMLLine(documentName,filename_".xml")
		}

	} s rs=""
	
	#;DeepSee artefacts
	do ..exportDeepSeeArtefacts()
	
	w !,!, "#; Exported to ", ..workdir()
	
    Q 1
}

/// import all from workdir
ClassMethod import(filemask = "*.xml;*.cls;*.mac;*.int;*.inc;*.dfi", qspec = "cku-d", ByRef err = "", recurse = 1, ByRef loaded = "", verbose = 1) As %Status
{
	#define push(%dir) s dirs( $i( dirs ) ) = %dir
	#define next(%i,%dir) s %i=$o( dirs( "" ), 1, %dir )  k:%i'="" dirs(%i)
	#define isDirectory(%type) ( %type = "D" )
	#define log w !, $piece(filename,..workdir(),2), " " w:sc "Ok" d:'sc $system.OBJ.DisplayError(sc)
	
	s sc = 1, dirs = "", dir = ..workdir() $$$push(dir)
	if verbose w "#; Importing from ", dir,!
	d ..setIgnore(.fm)
	for { $$$next(i,dir) Q:i=""  Q:dir=""

		s rs = ##class(%File).FileSetFunc( dir, filemask, , 1 )

		while rs.%Next() {
			s filename = rs.Name

			if $$$isDirectory(rs.Type) {
				if recurse $$$push(filename)
				continue
			}
			// check file filter
			if ..inFilter(.fm,filename) continue

			s ext = $zcvt($p( filename, ".", * ),"l")

			if (ext = "dfi") {
				s sc = ##class(%DeepSee.UserLibrary.Utils).%Import( filename, 1, 0, 0, "", .dsloaded )

			} else {
				// load classes only
				s sc = $system.OBJ.Load( filename, "k-d", .err, .loaded)
			}

			if verbose $$$log
			
	    }
		// compile all the loaded classes to obey dependencies
		s sc=$system.OBJ.CompileList( .loaded, "cukbr-d/multicompile",.err )
		
	}
	
	if verbose {
	
		if $D(err) {
			s i=$Order(err("")) 
			while i'="" {
			w !,err(i)
			s i=$O(err(i))
			}
		}
		
		w !,!,"#; Imported from ", ..workdir()
		}
	Q sc
}

ClassMethod exportDeepSeeArtefacts() As %Status
{
	set sc = $$$OK
	set artefacts = $listbuild("DeepSee.Variables","DeepSee.TermList","DeepSee.CalcMbrs")
	
	for i=1:1:$listlength(artefacts)
	{
		set artefact = $list(artefacts,i)
		continue:$data(@("^"_artefact))=0
		
		set artefact = artefact_".GBL"
		set filename = ..filename(artefact)
		do ..mkdir(filename)

		set sc = ..fixXMLLine(artefact, filename_".xml")
	}

	return sc
}

ClassMethod patch(filename = "", commitFrom = "", commitTo = "") As %Status
{
	s gln = ..gln()
	s git = @gln@("git")

	set:commitTo="" commitTo=1
	if (git = 0) {
		set:(commitFrom="")||(commitFrom=1) commitFrom=0
		set sc = ##class(dev.diff.gitLocal).buildDiff(..workdir(), "HEAD~"_commitTo, "HEAD~"_commitFrom, .items)
		return:$$$ISERR(sc) sc
	}elseif(git = 1) {
		set owner = @gln@("owner")
		set repository = @gln@("repository")
		set user = @gln@("user")
		set password = @gln@("password")
		set:commitFrom="" commitFrom=1
		
		set sc = ##class(dev.diff.gitHub).Get(.items, owner, repository, user, password, commitFrom, commitTo)
		return:$$$ISERR(sc) sc	
	}
	
	if (filename="") {
		set filename=$G(@gln@("projectName"),"patch")
		set filename=filename_$p($zdt($h,8)," ")_$tr($p($p($zdt($h)," ",2),":",1,2),":")_".xml"	
	}
	zw filename
	set sc = $system.OBJ.Export(.items,filename)
	
	return sc
}

ClassMethod fixXMLLine(documentName, filename) As %Status
{
	set stream = ##class(%Stream.FileBinary).%New()
	do stream.LinkToFile(filename)
	do $system.OBJ.ExportToStream(documentName, .stream)

	set matcher=##class(%Regex.Matcher).%New("<Export generator=.+>")
	set matcher.Text = stream.Read(stream.Size)
	set data = matcher.ReplaceFirst("<Export generator=""Cache"">")
	
	do stream.Clear()
	do stream.Write(data)
	return stream.%Save()
}

ClassMethod inFilter(ByRef filtermask, filename) As %Boolean
{
	s result=0
	for 
	{
		if '$d(filtermask($I(i))) quit
		set filter=$piece(filtermask(i),"*")
		if $length(filename,filter)>1 set result=1
	}

	quit result
}

/// get the filtermask for the repository.
/// looks for .gitignore file and applies all the lines to filters
ClassMethod setIgnore(ByRef filtermask)
{
	
	// working with .gitignore file
	// gitignore consists of masks of filtering files
	s filename=..workdir()_"/.gitignore"
	if '##class(%File).Exists(filename) quit
	s file=##class(%File).%New(filename)
	s sc=file.Open("R")
	if 'sc 
	{
		if verbose d $System.OBJ.DisplayError(sc) return
	}

	While 'file.AtEnd
	{
		s filtermask($I(filtermask))=file.ReadLine()
	}
	quit
}

/// get or set working directory for export/import source
ClassMethod workdir(workdir)
{
	set:$d(workdir) workdir = ##class(%File).NormalizeDirectory(workdir)
	s gln = ..gln() 
	s:$d(workdir) @gln = workdir
	
	///zu(12) namespace directory by default
	#define nsdir $zu(12,"")
	Q $g(@gln, $$$nsdir)
}

/// gl[obal] n[ame] - storage for settings
ClassMethod gln() [ CodeMode = expression, Private ]
{
"^"_$classname()
}

ClassMethod init(confile = "isc.json")
{
	q:..workdir()="" "workdir is empty"
	q:'##class(%File).Exists(..workdir()_confile) "configuration file: "_confile_" not found in "_..workdir()
	
	s stream=##class(%Stream.FileCharacter).%New()
	s sc=stream.LinkToFile(..workdir()_confile)
	s conf={}.%FromJSON(stream.Read($$$MaxCacheInt))
	
	s gln = "^dev.code"
	
	s @gln@("compileList")=conf.compileList
	s @gln@("projectName")=conf.projectName
	s @gln@("owner")=conf.owner
	s @gln@("repository")=conf.repository
	s @gln@("user")=conf.user
	s @gln@("password")=conf.password
	s @gln@("git")=conf.git
	s:@gln@("git")="" @gln@("git")=0
	
	w "compileList="_conf.compileList,!
	w "projectName="_conf.projectName,!
	w "owner="_conf.owner,!
	w "repository="_conf.repository,!
	w "user="_conf.user,!
	w "password="_conf.password,!
	w "git="_conf.git,!
	
	quit $$$OK
}

/// export release file for list and project settings
ClassMethod release()
{
	s gln=..gln()
	s list=$G(@gln@("compileList"))
	if list="" w "Nothing to release. Run init method first" quit

	s release=$G(@gln@("projectName"),"release")
	s release=release_$p($zdt($h,8)," ")_$tr($p($p($zdt($h)," ",2),":",1,2),":")_".xml"
	D $System.OBJ.Export(list,release)
	w "All objects with mask "_list_" has been exported to "_release
}

ClassMethod compile()
{
	s gln=..gln()
	s list=$G(@gln@("compileList"))
	if list="" w "Nothing to compile. Run init method first" quit
	d $System.OBJ.compile(list)
}

/// test.dfi -> /dfi/test.dfi
/// test.cls -> /cls/test.cls
/// testpkg.test.cls -> /cls/testpkg/test.cls
/// etc
ClassMethod filename(code)
{
	#define log(%dir,%sc) w !, "mkdir ", %dir, " ", sc

	s wd = ..workdir()

	if '##class(%File).DirectoryExists( wd ) {
		s sc = ##class(%File).CreateDirectoryChain( wd )
		$$$log(wd,sc)
	}

	s ext = $p( code, ".", * ), ext = $zcvt( ext, "l" )
	#; for each type - different directory

	s:ext'="" wd = ##class(%File).NormalizeDirectory( ext, wd )

	#; directory must exist before any call (%File).NormalizeFilename( , wd)
	if '##class(%File).DirectoryExists( wd ) {
		s sc = ##class(%File).CreateDirectoryChain( wd )
		$$$log(wd,sc)
	}

	s filename = ##class(%File).NormalizeFilename( code, wd )
	#; lowercase file extension
	s $p(filename,".",*)=ext
	//B:code="DPRep.Rest.JSON.cls" "L"
	#; for *.cls Package.Subpackage.ClassName.cls -> Folder/Subfolder/ClassName.cls
	if (ext="cls") || (ext="gbl") {
		s dirs = $piece( code, ".",1, *-2 ), dirs = $translate( dirs, ".", "/" )
		s relpath = dirs _ "/" _ $piece( code, ".", *-1, * ) ;
		s filename = ##class(%File).NormalizeFilename( relpath, wd )
	}

	Q filename
}

/// import from workdir all files with ts newer than code ts in db
ClassMethod importUpdated(filemask = "*.*", qspec = "cku-d", ByRef err = "", recurse = 1, ByRef loaded = "", verbose = 1) As %Status
{
	#define push(%dir) s dirs( $i( dirs ) ) = %dir
	#define next(%i,%dir) s %i=$o( dirs( "" ), 1, %dir )  k:%i'="" dirs(%i)
	#define isDirectory(%type) ( %type = "D" )
	#define log w !, $piece(filename,..workdir(),2)," " w:sc "Ok" d:'sc $system.OBJ.DisplayError( sc )

	s sc = 1, dirs = "", dir = ..workdir() $$$push(dir)
	if verbose w "#; Importing updated from ", dir,!
	d ..setIgnore(.fm)
	for { $$$next(i,dir) Q:i=""  Q:dir=""

		s rs = ##class(%File).FileSetFunc( dir, filemask, , 1 )

		while rs.%Next() {
		   s filename = rs.Name

		   if $$$isDirectory( rs.Type ) {
			 if ( recurse ) $$$push(filename) ;push directory
			 continue
		   }

			// check file filter
			if ..inFilter(.fm,filename) continue

		   s filets = rs.DateModified
		   s codename = ..codename( filename, .ext )
		   s codets = ..codets( codename, ext )
		   
		   #; w !, filename, $c(9), "(", filets, ")"
		   #; w !, codename, $c(9), "(", codets, ")"
		   
		   if ( filets '] codets ) continue
			 
		   if (ext = "dfi"){
				s sc = ##class(%DeepSee.UserLibrary.Utils).%Import( filename, 1, 0, 0, "", .dsloaded )
		   } else {

			   #; drop existing code before import ( purge DateModified )
			   #; s:codets'="" sc = ##class(%RoutineMgr).Delete( codename )
			   k err s sc = $system.OBJ.Load( filename, qspec, .err, .loaded)

		   }

		   if verbose $$$log
	    }
	}
	w:verbose !,"#; Imported updated from ", ..workdir()
	Q sc
}

/// presumable codename
ClassMethod codename(filename, ByRef ext = "")
{
	s ext = $p( filename, ".", * ), ext = $zcvt( ext, "l" )
	s path = ##class(%File).NormalizeDirectory( ext, ..workdir() )
	s codename = $p( filename, path, 2 )
	if ext = "dfi" {
		s fullname  = $tr( codename, "\", "/" ) ; return fullname for dfi in $$$IsWINDOWS
		Q $p( fullname, ".", 1, *-1 ) ;remove extension
	}
	if (ext ="cls")!(ext="int")!(ext="inc")!(ext="mac") s codename=$tr(codename,"\/","..")
	Q codename
}

ClassMethod codets(codename, ext)
{
	s ts = ""
	if ext'="dfi" {
		s ts = ##class(%RoutineMgr).TS( codename )
	} else {
		s sql="Select timeModified From %DeepSee_UserLibrary.FolderItem Where fullname = ?"
		s rs = ##class(%SQL.Statement).%ExecDirect( , sql, codename )
		if rs.%Next() {
			s utcts = rs.timeModified
			s utch = $zdth( utcts, 3, , 3 ) ;utc internal format
			s loch = $zdth( utch, -3 ) ; utc to local timezone
			s ts = $zdt( loch, 3, ,0 ) ; local timestamp*/
		}
	}
	Q $p( ts, "." ) ;remove ms
}

// fix "-" into dfi files

ClassMethod fixDashIntoName()
{
	s sql = "Select id, fullName as Name, documentName From %DeepSee_UserLibrary.FolderItem"
    s rs = ##class(%SQL.Statement).%ExecDirect( .stm, sql )
    while rs.%Next() {
		if $find(rs.Name, "-"){
			w rs.Name," -> "
			set item = ##class(%DeepSee.UserLibrary.FolderItem).%OpenId(rs.id)
			set item.name = $replace(item.name,"-"," ")
			w item.name,!
			do item.%Save()
		}
    }
    k rs
}

ClassMethod mkdir(filename As %String) As %Status
{
	s sc = $$$OK
	s path = ##class(%File).GetDirectory(filename) 
	if '##class(%File).DirectoryExists(path) 
	{
		s sc = ##class(%File).CreateDirectoryChain(path) 
		w !, "mkdir ", path, " ", sc 
	}
	return sc
}

ClassMethod getVersion() [ CodeMode = expression ]
{
"Version: "_..#version
}

ClassMethod checkMasks(name As %String, masks As %String) As %Boolean
{
	return:masks="" 1
	return:name="" 0
	
	set name = $zcvt(name,"l")
	set masks =  $zcvt(masks,"l")
	
	for i=1:1:$l(masks,",")
	{
		set pattern = "^"
		set mask = $p(masks, ",", i)
		
		for index=1:1:$l(mask)
		{
			set char = $e(mask, index)
    		set pattern = pattern _ $case(char,
    									  ".":"\.",
    									  "?":".",
    									  "*":".*",
    									     :char
    									  )	
		}
		set pattern = pattern _ "$|"
	}
	set pattern = $e(pattern,1,*-1)
	set matcher=##class(%Regex.Matcher).%New(pattern, name)
	do matcher.Locate() 
	return $select(matcher.Group="":0, 1:1)
}

}

