Class dev.deepsee
{

ClassMethod checkDataSource(onlyerror As %Boolean = 1)
{
	set sc = $$$OK
	&sql(DECLARE C1 CURSOR FOR SELECT ID into :id FROM %DeepSee_Dashboard.Definition)
	&sql(OPEN C1)
	&sql(FETCH C1)
	WHILE (SQLCODE = 0)
	{	
		set flag = 1
		set dashbord = ##class(%DeepSee.Dashboard.Definition).%OpenId(id)
		set widgets = dashbord.widgets
		
		for i=1:1:widgets.Count()
		{
			set widget = widgets.GetAt(i)
			set pivotName =  widget.dataSource
			set sc = ..getMdx(pivotName, .MDX)
			set sc = ..checkPivot(MDX)
			
			continue:sc&&onlyerror
			
			w:flag=1 dashbord.name,!
			w "   pivot: ",pivotName,"  status: "_$select(sc'=1:$System.Status.GetErrorText(sc),1:"OK"),!
			set flag = 0
		}
		&sql(FETCH C1) 
	}
	&sql(CLOSE C1)
}

ClassMethod checkPivot(MDX As %String) As %Status
{
	set sc = $$$OK
	set rs = ##class(%DeepSee.ResultSet).%New()
	
	set sc = rs.%PrepareMDX(MDX)
	return:$$$ISERR(sc) sc
	
	set sc = rs.%ExecuteAsynch()
	return:$$$ISERR(sc) sc
	
	return sc
}

ClassMethod getMdx(pPivotName As %String, Output MDX) As %Status
{
	#dim tPivot As %DeepSee.Dashboard.Pivot
	#dim tPivotTable As %DeepSee.Component.pivotTable
	set MDX = ""

	set tPivot = ##class(%DeepSee.UserLibrary.Utils).%OpenFolderItem(pPivotName,.sc)
	return:'$IsObject(tPivot) $$$OK
	return:$$$ISERR(sc) sc

	set tPivotTable = ##class(%DeepSee.Component.pivotTable).%New()
	set sc = tPivot.%CopyToComponent(tPivotTable)
	return:$$$ISERR(sc) sc

	set rs = tPivotTable.%CreateResultSet(.sc,,,,.MDX) // returns tQueryText - mdx without filters
	return:$$$ISERR(sc) sc
	
	set MDX = $TR(MDX,$C(10),"")
	
	return sc
}

}

