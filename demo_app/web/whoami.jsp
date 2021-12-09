<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"
    import="java.util.Enumeration"
    import="java.util.Iterator"
    import="java.util.Set"
    import="java.util.Base64"
    import="java.util.ArrayList"
    import="java.util.StringTokenizer"
    import="java.security.Principal"
    import="java.lang.reflect.Method"
    import="java.util.Arrays"
    import="javax.security.jacc.PolicyContext"
    import="javax.security.auth.Subject"
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
        String clazz = p.getClass().getName().toString();
        String simpleClassName = p.getClass().getSimpleName().toString();
        sbhtml.append("<br>Princial object: <br>");
        try {
            String[] roles = {};
            String claims = "null";
            if (simpleClassName.equals("JwtPrincipal")) {
                //Using IBM Securuty SSO Valve
                roles = (String[]) p.getClass().getMethod("getRoles").invoke(p);
                claims = (String) p.getClass().getMethod("getClaims").invoke(p).toString();

            } else if (simpleClassName.equals("DefaultJsonWebTokenImpl")) {
                //Probably using Liberty
                Method getRolesMethod  = p.getClass().getDeclaredMethod("getGroups");
                roles = (String[]) ((Set<String>) getRolesMethod.invoke(p)).toArray(new String[0]);
                String realm = p.getClass().getMethod("getIssuer").invoke(p).toString();
                for(int j = 0; j < roles.length; j++) {
                    roles[j] = realm + "/"  +roles[j];
                }
                Set<String> claimNames = (Set<String>) p.getClass().getMethod("getClaimNames").invoke(p);
                sbhtml.append("claim names: " + claimNames.toString());
                StringBuffer claimsBuffer = new StringBuffer();
                claimsBuffer.append("{");
                for(String claim: claimNames) {
                claimsBuffer.append(claim + ":" + (String) p.getClass().getMethod("getClaim", new Class<?>[]{String.class}).invoke(p, new Object[]{claim}).toString() + ",");
                }
                claimsBuffer.append("}");
                claims = claimsBuffer.toString();
            } else if(simpleClassName.equals("NamePrincipal")) {
                Subject s = (Subject) PolicyContext.getContext("javax.security.auth.Subject.container");
                //sbhtml.append("FINDME: " + Arrays.toString( s.getClass().getMethods() ) + "<br>");
                //System.getProperty("java.class.path")
                //Set principals =  s.getPrincipals();
                //sbhtml.append("FINDME: " + System.getProperty("java.class.path") + "<br>");
                Set creds = s.getPrivateCredentials();
                creds.addAll( s.getPublicCredentials() );
                creds.addAll( s.getPrincipals() );
                for(Object o: creds) {
                    if (o.getClass().getSimpleName().toString().equals("SecurityIdentity")) {
                        //sbhtml.append( "<BR>" + .toString() );
                        Iterable iterable = (Iterable) o.getClass().getMethod("getRoles").invoke(o);
                        Iterator roleIter = (Iterator) iterable.iterator();
                        ArrayList<String> roleArray =  new ArrayList<String>();
                        while(roleIter.hasNext()) {
                            roleArray.add(roleIter.next().toString());
                        }
                        roles = roleArray.toArray(new String[roleArray.size()]);
                    } else if(o.getClass().getSimpleName().equals("BearerTokenCredential")) {
                        String b64Claims = o.getClass().getMethod("getToken").invoke(o).toString().split("\\.")[1];
                        claims = new String( Base64.getDecoder().decode(b64Claims) );
                        //sbhtml.append("FINDME: " + o.getClass().getName().toString() + "::" + b64Claims + "<br>");
                    }
                    //sbhtml.append("<BR>" + o.getClass().getName().toString() + ": " +Arrays.toString(o.getClass().getMethods()) + "<BR>");
                    //sbhtml.append( o.getClass().getMethod("getName").invoke(o).toString() + "<BR>" );
                }
                //roles = new String[]{"Cannot get a list of roles from Jboss/Wildfly, use the manual role checker"};
            } else {
                sbhtml.append(clazz + " unknown");
            }
            sbhtml.append("<table border=\"1\">");
                sbhtml.append("<tr><th>Principal</th><th>Roles</th><th>Claims</th><th>Methods</th></tr>");
            sbhtml.append("<tr><td>" + htmlEncode(clazz) + "</td><td>");
            for(int i = 0 ; i < roles.length; i++) {
                sbhtml.append(roles[i] + "<br>");
            }
            sbhtml.append("</td><td>" + claims + "</td><td>");
            Method[] m = p.getClass().getMethods();
            for(int k = 0; k < m.length; k++) {
                sbhtml.append(m[k].toString() + "<br>");
            }
            sbhtml.append("</td></tr>");
            sbhtml.append("</table>");
        } catch (Throwable t) {
            sbhtml.append(simpleClassName + " reflection failed :(. No mapping for class [" + clazz + "]");
            //sbhtml.append("<br>" + htmlEncode(t.getCause().toString()));
            sbhtml.append("<br>" + htmlEncode(t.getMessage()));
            sbhtml.append("<br>" + htmlEncode(Arrays.toString(t.getStackTrace())));
        }
    }

    void dumpSession(StringBuffer sbhtml, HttpSession ctx) {
    sbhtml.append("<br>HttpSession");
        sbhtml.append("<table border=\"1\">");
        sbhtml.append("<tr><th>Name</th><th>Values</th></tr>");
        if (ctx.getAttributeNames() != null) {
            for (Enumeration attributesNames = ctx.getAttributeNames(); attributesNames.hasMoreElements(); ) {
                //String attrName = (String) attributesNames.nextElement();
                String attrName = attributesNames.nextElement().toString();
                //String[] attrValues = (String[]) ctx.getAttribute(attrName);
                String attrValues = ctx.getAttribute(attrName).toString();

                sbhtml.append("<tr><td>" + htmlEncode(attrName) + "</td><td>");

                sbhtml.append("<table border=\"1\">");
                if (attrValues != null) {
                    //for (int x = 0; x < attrValues.length; x++) {
                    //    sbhtml.append("<tr><td>"+htmlEncode(attrValues[x])+"</td></tr>");
                    //}
                    sbhtml.append("<tr><td>"+htmlEncode(attrValues)+"</td></tr>");
                }
                sbhtml.append("</table>");
                sbhtml.append("</td>");
            }
            sbhtml.append("</table>");
        }
        sbhtml.append("</td></tr>");
        sbhtml.append("</table>");
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
    dumpSession(sbhtml, request.getSession());
    sbhtml.append("</div>");
%>
</head>
<body>
<h1>Subject details</h1>
<%=sbhtml.toString()%>

<br>
<A href="index.html">Demo Application Index</A>

</body>
</html>
