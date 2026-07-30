package cmd

import (
	"testing"

	"github.com/grovetools/core/pkg/mux"
	"github.com/stretchr/testify/assert"
)

// `chat` was the last submitter in the ecosystem that queued jobs with no
// routing. The daemon builds its JobInfo from this request alone, so an empty
// AgentTarget is not a default the executor can fill in later — it fails the job
// with "agent_target not set: job submitted without routing context" seconds
// after the plugin was told the submission succeeded.
func TestChatSubmitRequest_CarriesAgentTarget(t *testing.T) {
	t.Setenv(mux.EnvTuimuxPTY, "1")

	req := chatSubmitRequest("/plans/demo", "job.md")
	assert.Equal(t, mux.AgentTargetTuimux, req.AgentTarget, "AgentTarget must be derived from the caller's environment")
	assert.Equal(t, "/plans/demo", req.PlanDir)
	assert.Equal(t, "job.md", req.JobFile)
}

// A grove terminal that is not a tuimux pane routes natively; the point of the
// assertion is that the target tracks the environment rather than being pinned
// to one value.
func TestChatSubmitRequest_TracksEnvironment(t *testing.T) {
	t.Setenv(mux.EnvTuimuxPTY, "")
	t.Setenv(mux.EnvGroveTerminal, "1")

	assert.Equal(t, mux.AgentTargetNative, chatSubmitRequest("/plans/demo", "job.md").AgentTarget)
}
