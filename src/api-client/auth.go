package penpot

// TokenClaims holds the decoded claims from a verified token.
type TokenClaims struct {
	// The token type (e.g. "access", "verify-email", "auth").
	Type string `json:"type"`
	// Profile ID associated with the token, if any.
	ProfileID UUID `json:"profile-id"`
	// Any additional claims from the token.
	Data map[string]any `json:"-"`
}

// VerifyToken verifies a raw token string and returns its claims.
// Does not require authentication.
func (c *Client) VerifyToken(token string) (*TokenClaims, error) {
	type req struct {
		Token string `json:"token"`
	}
	var claims TokenClaims
	if err := c.post("verify-token", req{Token: token}, &claims); err != nil {
		return nil, err
	}
	return &claims, nil
}
