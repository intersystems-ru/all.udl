Class dev.diff.utils
{

Parameter TRACKEDEXT As List = {$lb("xml", "cls", "csp", "csr", "mac", "int", "bas", "inc", "gbl", "prj", "obj", "pkg", "gof", "dfi", "pivot", "dashboard")};

ClassMethod ToCacheName(ByRef filename)
{
	if $get(filename)="" break
	do:$L($zcvt(filename,"L"),".xml")>1 ..getExtension(.filename)
	set str = $Select(
		$L(filename,"cls/")>1:$Replace($P(filename,"cls/",2),"/","."),
	    $L(filename,"csp/")>1:$Replace($P(filename,"csp/",2),"/","."),
	    $L(filename,"dfi/")>1:$Replace($P(filename,"dfi/",2),"/","-"),
	    $L(filename,"inc/")>1:$Replace($P(filename,"inc/",2),"/","."),
	    $L(filename,"web/")>1:$Replace($P(filename,"web/",2),"/","."),
	    1:$Replace(filename,"/",".")
	   )
	set filename = $P(str,".",1,*-1)_"."_ $ZCVT($P(str,".",*),"U")
}

ClassMethod isRelevantFile(file As %String) As %Boolean
{
	set ext = $select($length(file, ".")=1:"", 1:$piece(file, ".", *))
	quit $lf(..#TRACKEDEXT, ext)>0
}

ClassMethod getExtension(ByRef filename)
{
	if ($L(filename,"dfi/") > 1) {
		set filename = $extract(filename,1,*-4)_".DFI"
	}elseif ($L(filename,"cls/") > 1) {
		set filename = $extract(filename,1,*-4)_".CLS"
	}elseif ($L(filename,"gbl/") > 1) {
		set filename = $p($extract(filename,1,*-4),"gbl/",2)
	}
}

ClassMethod getLocalGitPathByWorkdir(workdir As %String) As %String
{
	set path = ""
	if ($L(workdir,"/") > 1) {
		if ($P(workdir,"/",*) = "") {
			set path = $P(workdir,"/",*-1)
		}else {
			set path = $P(workdir,"/",*)
		}

	}else {
		if ($P(workdir,"\",*) = "") {
			set path = $P(workdir,"\",*-1)
		}else {
			set path = $P(workdir,"\",*)
		}
	}
	
	return path_"/"
}

}

