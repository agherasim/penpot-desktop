package penpot

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
)

const defaultBaseURL = "https://design.penpot.app/api/rpc/command"

// Client is a Penpot API client.
type Client struct {
	baseURL    string
	httpClient *http.Client
	token      string
}

// Option is a functional option for Client.
type Option func(*Client)

// WithBaseURL overrides the base URL (for self-hosted instances).
func WithBaseURL(u string) Option {
	return func(c *Client) { c.baseURL = u }
}

// WithToken sets a Bearer access token.
func WithToken(token string) Option {
	return func(c *Client) { c.token = token }
}

// New creates a new Penpot API client.
func New(opts ...Option) *Client {
	c := &Client{
		baseURL:    defaultBaseURL,
		httpClient: &http.Client{},
	}
	for _, o := range opts {
		o(c)
	}
	return c
}

func (c *Client) post(command string, body, dst any) error {
	u := fmt.Sprintf("%s/%s", c.baseURL, command)

	b, err := json.Marshal(body)
	if err != nil {
		return fmt.Errorf("penpot: marshal: %w", err)
	}

	req, err := http.NewRequest(http.MethodPost, u, bytes.NewReader(b))
	if err != nil {
		return fmt.Errorf("penpot: build request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	if c.token != "" {
		req.Header.Set("Authorization", "Token "+c.token)
	}

	return c.exec(req, dst)
}

func (c *Client) get(command string, params map[string]string, dst any) error {
	u, err := url.Parse(fmt.Sprintf("%s/%s", c.baseURL, command))
	if err != nil {
		return fmt.Errorf("penpot: build URL: %w", err)
	}
	q := u.Query()
	for k, v := range params {
		q.Set(k, v)
	}
	u.RawQuery = q.Encode()

	req, err := http.NewRequest(http.MethodGet, u.String(), nil)
	if err != nil {
		return fmt.Errorf("penpot: build request: %w", err)
	}
	req.Header.Set("Accept", "application/json")
	if c.token != "" {
		req.Header.Set("Authorization", "Token "+c.token)
	}

	return c.exec(req, dst)
}

func (c *Client) exec(req *http.Request, dst any) error {
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("penpot: http: %w", err)
	}
	defer resp.Body.Close()

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("penpot: read body: %w", err)
	}

	if resp.StatusCode >= 400 {
		return parseAPIError(resp.StatusCode, data)
	}

	if dst != nil && len(data) > 0 {
		if err := json.Unmarshal(data, dst); err != nil {
			return fmt.Errorf("penpot: unmarshal: %w", err)
		}
	}
	return nil
}

// APIError is an error returned by the Penpot API.
type APIError struct {
	StatusCode int    `json:"-"`
	Code       string `json:"code"`
	Type       string `json:"type"`
	Message    string `json:"message"`
	Hint       string `json:"hint"`
}

func (e *APIError) Error() string {
	msg := fmt.Sprintf("penpot %d", e.StatusCode)
	if e.Code != "" {
		msg += " " + e.Code
	}
	if e.Message != "" {
		msg += ": " + e.Message
	}
	if e.Hint != "" {
		msg += " (" + e.Hint + ")"
	}
	return msg
}

func parseAPIError(status int, body []byte) error {
	e := &APIError{StatusCode: status}
	_ = json.Unmarshal(body, e)
	if e.Message == "" {
		e.Message = string(body)
	}
	return e
}
