package ibm.security.verify.sso.valve;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.apache.catalina.realm.GenericPrincipal;

public class JwtPrincipal extends GenericPrincipal {

	/**
	 * 
	 */
	private static final long serialVersionUID = 1L;
	private Map<String, Object> claims = new HashMap<String, Object>();

	public JwtPrincipal(String name, Map<String, Object> claims, List<String> roles) {
		super(name, roles);
		this.claims = claims;
	}
	
	public Map<String, Object> getClaims() {
		return this.claims;
	}

}
