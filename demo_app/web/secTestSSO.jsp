<!-- Copyright contributors to the IBM Security Integrations project -->
<%@ page language="java" contentType="text/html; charset=ISO-8859-1"
    pageEncoding="ISO-8859-1"
    import="java.util.StringTokenizer"
%>
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-1">
<title>SecTest SSO Page</title>
<LINK REL=StyleSheet HREF="main.css" TYPE="text/css" MEDIA=screen>
</head>
<body>

<%!
    /**
     * Html-encode to guard against CSS and/or SQL injection attacks
     * @param pText string that may contain special characters like &, <, >, "
     * @return encoded string with offending characters replaced with innocuous content
     * like <code>&amp</code>, <code>&gt</code>, <code>&lt</code> or <code>&quot</code>.
     */
    String htmlEncode(String pText) {
        String result = null;
        if (pText != null) {
            StringTokenizer tokenizer = new StringTokenizer(pText, "&<>\"", true);
            int tokenCount = tokenizer.countTokens();

            /* no encoding's needed */
            if (tokenCount == 1)
                return pText;

            /*
             * text.length + (tokenCount * 6) gives buffer large enough so no
             * addition memory would be needed and no costly copy operations would
             * occur
             */
            StringBuffer buffer = new StringBuffer(pText.length() + tokenCount * 6);
            while (tokenizer.hasMoreTokens()) {
                String token = tokenizer.nextToken();
                if (token.length() == 1) {
                    switch (token.charAt(0)) {
                    case '&':
                        buffer.append("&amp;");
                        break;
                    case '<':
                        buffer.append("&lt;");
                        break;
                    case '>':
                        buffer.append("&gt;");
                        break;
                    case '"':
                        buffer.append("&quot;");
                        break;
                    default:
                        buffer.append(token);
                    }
                } else {
                    buffer.append(token);
                }
            }
            result = buffer.toString();
        }
        return result;
    }
%>

<h2>SecTestWeb SSO Page</h2>
This test page extracts the user information from the HTTP request to verify successful SSO to a Java webserver. This is verified
using the "security-constraint" attribute of a Java Web Application deployment, usually in the WEB-INF/web.xml file.<br>
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
    String role = htmlEncode(request.getParameter("role"));
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
