<%
	if(session!=null) {
		session.invalidate();
	}
	response.sendRedirect("/../pkmslogout");
%>