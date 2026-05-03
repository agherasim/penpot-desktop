package penpot

import "time"

// --- Types ---

type File struct {
	ID         UUID      `json:"id"`
	Name       string    `json:"name"`
	ProjectID  UUID      `json:"projectId"`
	IsShared   bool      `json:"isShared"`
	CreatedAt  time.Time `json:"createdAt"`
	ModifiedAt time.Time `json:"modifiedAt"`
	Revn       int       `json:"revn"`
	Features   []string  `json:"features"`
}

type Page struct {
	ID      UUID   `json:"id"`
	Name    string `json:"name"`
	Objects any    `json:"objects,omitempty"`
}

type Change map[string]any

// --- Requests ---

type CreateFileReq struct {
	Name      string   `json:"name"`
	ProjectID UUID     `json:"projectId"`
	ID        UUID     `json:"id,omitempty"`
	IsShared  bool     `json:"isShared,omitempty"`
	Features  []string `json:"features,omitempty"`
}

type UpdateFileReq struct {
	ID           UUID     `json:"id"`
	SessionID    UUID     `json:"sessionId"`
	Revn         int      `json:"revn"`
	Vern         int      `json:"vern"`
	Changes      []Change `json:"changes,omitempty"`
	SkipValidate bool     `json:"skipValidate,omitempty"`
	Features     []string `json:"features,omitempty"`
}

type GetPageReq struct {
	FileID   UUID   `json:"fileId"`
	PageID   UUID   `json:"pageId,omitempty"`
	ShareID  UUID   `json:"shareId,omitempty"`
	ObjectID UUID   `json:"objectId,omitempty"`
}

// --- Methods ---

func (c *Client) CreateFile(req CreateFileReq) (*File, error) {
	var f File
	return &f, c.post("create-file", req, &f)
}

func (c *Client) GetFile(id UUID, features []string) (*File, error) {
	var f File
	return &f, c.get("get-file", uuidParams("id", id, features), &f)
}

func (c *Client) GetFileInfo(id UUID) (*File, error) {
	var f File
	return &f, c.get("get-file-info", map[string]string{"id": id}, &f)
}

func (c *Client) GetFileSummary(id UUID) (any, error) {
	var s any
	return s, c.get("get-file-summary", map[string]string{"id": id}, &s)
}

func (c *Client) UpdateFile(req UpdateFileReq) (*File, error) {
	var f File
	return &f, c.post("update-file", req, &f)
}

func (c *Client) DeleteFile(id UUID) error {
	return c.post("delete-file", map[string]any{"id": id}, nil)
}

func (c *Client) RenameFile(id UUID, name string) (*File, error) {
	var f File
	return &f, c.post("rename-file", map[string]any{"id": id, "name": name}, &f)
}

func (c *Client) GetProjectFiles(projectID UUID) ([]File, error) {
	var files []File
	return files, c.get("get-project-files", map[string]string{"projectId": projectID}, &files)
}

func (c *Client) SetFileShared(id UUID, shared bool) error {
	return c.post("set-file-shared", map[string]any{"id": id, "isShared": shared}, nil)
}

func (c *Client) SearchFiles(teamID, searchTerm string) ([]File, error) {
	var files []File
	return files, c.post("search-files", map[string]any{"teamId": teamID, "searchTerm": searchTerm}, &files)
}

func (c *Client) GetPage(req GetPageReq) (*Page, error) {
	params := map[string]string{"fileId": req.FileID}
	if req.PageID != "" {
		params["pageId"] = req.PageID
	}
	if req.ShareID != "" {
		params["shareId"] = req.ShareID
	}
	var page Page
	return &page, c.get("get-page", params, &page)
}

func (c *Client) GetFileLibraries(fileID UUID) ([]File, error) {
	var files []File
	return files, c.get("get-file-libraries", map[string]string{"fileId": fileID}, &files)
}

func (c *Client) LinkFileToLibrary(fileID, libraryID UUID) error {
	return c.post("link-file-to-library", map[string]any{"fileId": fileID, "libraryId": libraryID}, nil)
}

func (c *Client) UnlinkFileFromLibrary(fileID, libraryID UUID) error {
	return c.post("unlink-file-from-library", map[string]any{"fileId": fileID, "libraryId": libraryID}, nil)
}

func (c *Client) HasFileLibraries(fileID UUID) (bool, error) {
	var result struct {
		Has bool `json:"has"`
	}
	return result.Has, c.get("has-file-libraries", map[string]string{"fileId": fileID}, &result)
}

func (c *Client) GetTeamSharedFiles(teamID UUID) ([]File, error) {
	var files []File
	return files, c.get("get-team-shared-files", map[string]string{"teamId": teamID}, &files)
}

func (c *Client) GetTeamRecentFiles(teamID UUID) ([]File, error) {
	var files []File
	return files, c.get("get-team-recent-files", map[string]string{"teamId": teamID}, &files)
}

func (c *Client) GetTeamDeletedFiles(teamID UUID) ([]File, error) {
	var files []File
	return files, c.get("get-team-deleted-files", map[string]string{"teamId": teamID}, &files)
}

// uuidParams builds params for a GET with an id and optional features list.
func uuidParams(key, id string, features []string) map[string]string {
	p := map[string]string{key: id}
	// features last value wins per key; server accepts repeated params
	for _, f := range features {
		p["features"] = f
	}
	return p
}
