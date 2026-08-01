package cmd

import (
	"testing"

	"github.com/grovetools/core/pkg/models"
	"github.com/grovetools/core/pkg/workspace"
	"github.com/stretchr/testify/assert"
)

func TestRelevantToCwd(t *testing.T) {
	cases := []struct {
		name string
		cwd  string
		path string
		want bool
	}{
		{"same path", "/a/b", "/a/b", true},
		{"workspace contains cwd", "/a/b/sub/dir", "/a/b", true},
		{"cwd contains workspace", "/a", "/a/b", true},
		{"unrelated sibling", "/a/b", "/a/c", false},
		// The boundary cases: a plain string prefix would call these relevant
		// and leak a neighbouring repo's churn into an editor that is not in it.
		{"sibling sharing a name prefix", "/a/b", "/a/bc", false},
		{"cwd sharing a name prefix", "/a/bc", "/a/b", false},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			assert.Equal(t, tc.want, relevantToCwd(tc.cwd, tc.path))
		})
	}
}

func TestContainingWorkspace(t *testing.T) {
	at := func(path string) *models.EnrichedWorkspace {
		return &models.EnrichedWorkspace{WorkspaceNode: &workspace.WorkspaceNode{Path: path}}
	}

	workspaces := []*models.EnrichedWorkspace{
		at("/repos/eco"),
		at("/repos/eco/core"),
		at("/repos/other"),
		nil, // a nil entry must not panic the scan
		{},  // nor must one with no workspace node
	}

	// The longest containing workspace wins: an editor inside core is looking
	// at core, not at the ecosystem root that also contains it.
	assert.Equal(t, "/repos/eco/core", containingWorkspace("/repos/eco/core/pkg", workspaces))
	assert.Equal(t, "/repos/eco/core", containingWorkspace("/repos/eco/core", workspaces))
	assert.Equal(t, "/repos/eco", containingWorkspace("/repos/eco/daemon", workspaces))

	// Outside every workspace there is nothing honest to focus.
	assert.Equal(t, "", containingWorkspace("/elsewhere", workspaces))

	// A name-prefix sibling must not be mistaken for a container — focus is an
	// exact-key claim in the daemon, so a wrong path silently focuses nothing.
	assert.Equal(t, "", containingWorkspace("/repos/ecosystem", []*models.EnrichedWorkspace{
		at("/repos/eco"),
	}))
}
