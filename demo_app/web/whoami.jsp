<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"
    import="java.util.Enumeration"
    import="java.util.Iterator"
    import="java.util.Set"
    import="java.util.StringTokenizer"
    import="javax.security.auth.Subject"
    import="java.security.Principal"
%>
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<meta http-equiv="Pragma" content="no-cache">
<title>Dump the User's Subject</title>
<%!
    /**
     * Html-encode to guard against CSS and/or SQL injection attacks
     * @param pText string that may contain special characters like &, <, >, "
     * @return encoded string with offending characters replaced with innocuous content
     * like <code>&amp</code>, <code>&gt</code>, <code>&lt</code> or <code>&quot</code>.
     */
    String htmlEncode(String pText)
    {
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


    void dumpRoles(StringBuffer sbhtml, Principal p) {
        //First work out what kind of principal we have
        String clazz = p.getClass().getSimpleName().toString();
        sbhtml.append("<br>Princial object: ");
        if(clazz == "GeneralPrincipal") {
            //Tomcat!!!
            sbhtml.append("<table border=\"1\">");
            sbhtml.append("<tr><th>Principal</th><th>Roles</th></tr>");
            org.apache.catalina.realm.GenericPrincipal gp = (org.apache.catalina.realm.GenericPrincipal) p;
            sbhtml.append("<tr><td>" + htmlEncode(clazz) + "</td><td>");
            for(int i = 0 ; i < gp.getRoles().length; i++) {
                sbhtml.append(gp.getRoles()[i] + "\n");
            }
            sbhtml.append("</td></tr>");
            sbhtml.append("</table>");
        } else {
            sbhtml.append(clazz + " unknown");
        }
    }

    void dumpSession(StringBuffer sbhtml, ServletContext ctx) {
        sbhtml.append("<br>Attributes");
        sbhtml.append("<table border=\"1\">");
        sbhtml.append("<tr><th>Name</th><th>Values</th></tr>");
        if (ctx.getAttributeNames() != null) {
            for (Enumeration attributesNames = ctx.getAttributeNames(); attributesNames.hasMoreElements(); ) {
                String attrName = (String) attributesNames.nextElement();
                String[] attrValues = (String[]) ctx.getAttribute(attrName);

                sbhtml.append("<tr><td>" + htmlEncode(attrName) + "</td><td>");

                sbhtml.append("<table border=\"1\">");
                if (attrValues != null) {
                    for (int x = 0; x < attrValues.length; x++) {
                        sbhtml.append("<tr><td>"+htmlEncode(attrValues[x])+"</td></tr>");
                    }
                }
                sbhtml.append("</table>");
                sbhtml.append("</td>");
            }
            sbhtml.append("</table>");
        }
        sbhtml.append("</td></tr>");
        sbhtml.append("</table>");
    }

    String getPrincipalName(Subject s) {
        String result = null;
        Set principalSet = s.getPrincipals();
        if (principalSet != null && principalSet.size() > 0) {
            Principal p = (Principal) principalSet.iterator().next();
            result = p.getName();
        }
        return result;
    }

%>

<%
    Principal p = request.getUserPrincipal();
    if (p == null || p.getName() == null) {
        throw new Exception("Authenticate");
    }
    // dump the html version of token contents to a string buffer
    StringBuffer sbhtml = new StringBuffer();
    sbhtml.append("<div>");
    sbhtml.append("Username: " + htmlEncode(p.getName()));
    sbhtml.append("</div>");
    sbhtml.append("<div>");
    dumpRoles(sbhtml, p);
    sbhtml.append("</div>");
    dumpSession(sbhtml, request.getSession().getServletContext());
    sbhtml.append("</div>");
%>
</head>
<body>
<h1>Subject details</h1>
<%=sbhtml.toString()%>
</body>
</html>
