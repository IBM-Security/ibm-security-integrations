/** Copyright contributors to the IBM Security Integrations project */
package ibm.security.verify.sso.valve;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.security.KeyStore;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.security.UnrecoverableKeyException;
import java.security.cert.CertificateException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.apache.catalina.Authenticator;
import org.apache.catalina.LifecycleException;
import org.apache.catalina.connector.Request;
import org.apache.catalina.connector.Response;
import org.apache.catalina.realm.GenericPrincipal;
import org.apache.catalina.valves.ValveBase;
import org.apache.juli.logging.Log;
import org.apache.juli.logging.LogFactory;
import org.jose4j.jwt.JwtClaims;
import org.jose4j.jwt.MalformedClaimException;
import org.jose4j.jwt.consumer.InvalidJwtException;
import org.jose4j.jwt.consumer.JwtConsumer;
import org.jose4j.jwt.consumer.JwtConsumerBuilder;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletResponse;


public class JwtValve extends ValveBase implements Authenticator {

    private static final String CLAZZ = JwtValve.class.getName();
    private static final Log LOG = LogFactory.getLog(JwtValve.class);

    private String headerName = "Authorization";
    private String issuer = "localhost";
    private String audience = "localhost";
    private boolean jwe = false;
    private String signKeyAlias = "alias";
    private String encryptKeyAlias = "alias";
    private String keyStorePath = "/default/key.store";
    private String keyStorePassword = "password";
    private KeyStore keyStore;
    private String usernameAtribute = "sub";
    private String groupsAttribute = "groups";


    public void setHeaderName(String name) {
        this.headerName = name;
    }

    public void setIssuer(String iss) {
        this.issuer = iss;
    }

    public void setAudience(String aud) {
        this.audience = aud;
    }

    public void setJwe(String jwe) {
        this.jwe = Boolean.valueOf(jwe);
    }

    public void setSignKeyAlias(String alias) {
        this.signKeyAlias = alias;
    }

    public void setEncryptKeyAlias(String alias) {
        this.encryptKeyAlias = alias;
    }

    public void setKeyStorePath(String path) {
        this.keyStorePath = path;
    }

    public void setKeyStorePassword(String secret) {
        this.keyStorePassword = secret;
    }

    public void setUsernameAttribute(String sub) {
        this.usernameAtribute = sub;
    }

    public void setGroupsAttribute(String groups) {
        this.groupsAttribute = groups;
    }

    @Override
    public void logout(Request arg0) {
        LOG.debug("Enter " + CLAZZ + ".logout()");
        LOG.debug("Exit " + CLAZZ + ".logout()");
    }
 
    @Override
    public void invoke(Request req, Response rsp) throws IOException, ServletException {
        LOG.trace("Enter " + CLAZZ + ".invoke()");
        if(authenticate(req, rsp)) {
            LOG.debug(CLAZZ + ".authenticate() was successful. Principal set.");
        } else {
            LOG.debug(CLAZZ + ".authenticate() failed.");
        }
        getNext().invoke(req, rsp);
        LOG.trace("Exit " + CLAZZ + ".invoke()");
    }

    @Override
    public boolean authenticate(Request req, HttpServletResponse rsp) throws IOException {
        try {
            String bearerToken = req.getHeader(this.headerName);
            if (bearerToken == null || !bearerToken.toLowerCase().startsWith("bearer")) {
                LOG.debug("Authorization header has invalid format");
                return false;
            }
            String jwt = bearerToken.replaceAll("(?i)Bearer (.*)", "$1");
            LOG.debug("Found authorization bearer JWT: " + jwt);
            JwtClaims claims = this.jwe ? verifyEncryptedJwt(jwt) : verifySignedJwt(jwt);
            GenericPrincipal user = generatePrincipal(claims);
            req.setUserPrincipal(user);
            return true;
        } catch (NoSuchAlgorithmException | UnrecoverableKeyException | KeyStoreException |
                InvalidJwtException | MalformedClaimException e) {
            LOG.error(e.getMessage(), e);
        }
        return false;
    }


    private JwtClaims verifyEncryptedJwt(String jwe)
            throws UnrecoverableKeyException, KeyStoreException, NoSuchAlgorithmException, InvalidJwtException {
        JwtConsumer jwtConsumer = new JwtConsumerBuilder()
                .setRequireSubject()
                .setExpectedIssuer(this.issuer)
                .setExpectedAudience(this.audience)
                .setDecryptionKey(loadKeystore().getKey(this.encryptKeyAlias, this.keyStorePassword.toCharArray()))
                .setVerificationKey(loadKeystore().getCertificate(this.signKeyAlias).getPublicKey())
                .build(); // create the JwtConsumer instance
        return jwtConsumer.processToClaims(jwe);
    }

    private JwtClaims verifySignedJwt(String jws) throws KeyStoreException, InvalidJwtException {
        JwtConsumer jwtConsumer = new JwtConsumerBuilder()
                .setAllowedClockSkewInSeconds(30)
                .setRequireSubject()
                .setExpectedIssuer(this.issuer)
                .setExpectedAudience(this.audience)
                .setVerificationKey(loadKeystore().getCertificate(this.signKeyAlias).getPublicKey())
                .build();
        return jwtConsumer.processToClaims(jws);
    }

    private GenericPrincipal generatePrincipal(JwtClaims jwt) throws MalformedClaimException {
        Map<String, Object> claims = jwt.getClaimsMap();
        Object maybeGroups = claims.get(this.groupsAttribute);
        List<String> roles = new ArrayList<String>();
        if(maybeGroups instanceof String) {
        	roles = Arrays.asList(((String) maybeGroups).split(","));
        } else if (maybeGroups instanceof List) {
        	roles = (List<String>) maybeGroups;
        } else if (maybeGroups instanceof String[]) {
        	roles = Arrays.asList((String[]) maybeGroups);
        }
        roles = roles.stream()
                     .map(s -> this.issuer + "/" + s)
                     .collect(Collectors.toList());
        return new JwtPrincipal((String) claims.get(this.usernameAtribute), claims, roles);
    }

    private KeyStore loadKeystore() {
        if (this.keyStore == null) {
            try (InputStream in = new FileInputStream(this.keyStorePath)) {
                this.keyStore = KeyStore.getInstance(KeyStore.getDefaultType());
                keyStore.load(in, this.keyStorePassword.toCharArray());
            } catch (KeyStoreException | IOException |  NoSuchAlgorithmException | CertificateException e) {
                LOG.error(e.getMessage(), e);
                throw new RuntimeException(e.getMessage(), e); //TODO
            }
        }
        return this.keyStore;
    }

    @Override
    public void login(String arg0, String arg1, Request arg2) {
        LOG.debug("Enter " + CLAZZ + ".login()");
        LOG.debug("Exit " + CLAZZ + ".login()");
    }
    
    @Override
    public void startInternal() throws LifecycleException {
        LOG.debug("Enter " + CLAZZ + ".startInternal()");
        super.startInternal();
        LOG.debug("Exit " + CLAZZ + ".startInternal()");
    }
    
    @Override
    public void stopInternal() throws LifecycleException {
        LOG.debug("Enter " + CLAZZ + ".stopInternal()");
        super.stopInternal();
        LOG.debug("Exit " + CLAZZ + ".stopInternal()");
    }

    public void sendUnauthorizedError(Request request, Response response, String message) throws IOException {
        response.sendError(HttpServletResponse.SC_UNAUTHORIZED, this.headerName + "was missing or id not contain "
                + "a valid JWT.");
    }

}
