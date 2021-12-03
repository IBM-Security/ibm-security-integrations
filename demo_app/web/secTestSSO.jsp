<%@ page language="java" contentType="text/html; charset=ISO-8859-1"
	pageEncoding="ISO-8859-1"%>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-1">
<title>SecTest SSO Page</title>
<LINK REL=StyleSheet HREF="main.css" TYPE="text/css" MEDIA=screen>
</head>
<body>


<h2>SecTestWeb SSO Page</h2>
This test page extracts the user information from the HTTP request to verify successful SSO to JBoss.<br>
<h3>UserPrincipal Check</h3>

<%
    boolean loggedin = false;
    if (request.getUserPrincipal() != null) {
    loggedin = true;
%>

<b>request.getUserPrincipal().getName():</b><br>
<%= request.getUserPrincipal().getName() %><br><br>
<%
    } else {
    loggedin = false;
    
%>
<br> request.getUserPrincipal() Returned null. <br>
<%
    }
%>

<h3>Request Get Commands</h3>

<b> request.getRemoteUser():</b><br>
<%= request.getRemoteUser() %><br><br>

<br>

<h3>Manual Role Checks</h3>
<p>Type the name of a role to check and press enter to check.<br>

<%
    String role = request.getParameter("role");
    if (role == null)
        role = "";
    if (role.length() > 0) {
        if (request.isUserInRole(role)) {
%>
		Granted
		<b><%= role %></b><br><br>
<%
        } else {
%>
  Not granted <b><%= role %></b><br><br>
<%
        }
    }
%>
<form method="GET">
<input type="text" name="role" value="<%= role %>">
</form>
<br>
<A href="index.html">Configuration Test Application Index</A>
</body>
</html>
