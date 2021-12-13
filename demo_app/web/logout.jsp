<!-- Copyright contributors to the IBM Security Integrations project -->
<%
	if(session!=null) {
		session.invalidate();
	}
	response.sendRedirect("/../pkmslogout");
%>
