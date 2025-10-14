package tests

import (
	"net/http"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestWebAppModuleBasic tests the basic functionality of the web app module
func TestWebAppModuleBasic(t *testing.T) {
	t.Parallel()

	// Configure Terraform options
	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/basic",
		NoColor:      true,
		Vars: map[string]interface{}{
			"environment": "test",
		},
	}

	// Clean up resources with "terraform destroy" at the end of the test
	defer terraform.Destroy(t, terraformOptions)

	// Run "terraform init" and "terraform apply"
	terraform.InitAndApply(t, terraformOptions)

	// Test outputs
	webAppURL := terraform.Output(t, terraformOptions, "web_app_url")
	webAppHostname := terraform.Output(t, terraformOptions, "web_app_hostname")
	principalID := terraform.Output(t, terraformOptions, "managed_identity_principal_id")

	// Validate outputs are not empty
	assert.NotEmpty(t, webAppURL, "Web app URL should not be empty")
	assert.NotEmpty(t, webAppHostname, "Web app hostname should not be empty")
	assert.NotEmpty(t, principalID, "Managed identity principal ID should not be empty")

	// Validate URL format
	assert.Contains(t, webAppURL, "https://", "Web app URL should use HTTPS")
	assert.Contains(t, webAppURL, webAppHostname, "Web app URL should contain the hostname")

	// Test HTTP accessibility with retry logic
	validateWebAppAccessibility(t, webAppURL)
}

// validateWebAppAccessibility tests if the web app is accessible via HTTP
func validateWebAppAccessibility(t *testing.T, url string) {
	maxRetries := 10
	retryInterval := 30 * time.Second

	for i := 0; i < maxRetries; i++ {
		resp, err := http.Get(url)
		if err == nil {
			defer resp.Body.Close()
			
			// Check if we get a valid HTTP response (even if it's an error page)
			// A newly created web app might return 403, 404, or 503 initially
			if resp.StatusCode < 500 {
				t.Logf("Web app is accessible at %s (Status: %d)", url, resp.StatusCode)
				
				// Validate HTTPS redirect is working
				assert.True(t, resp.TLS != nil || resp.Request.URL.Scheme == "https", 
					"Response should be over HTTPS")
				
				return
			}
		}

		if i < maxRetries-1 {
			t.Logf("Attempt %d/%d failed to access %s, retrying in %v...", 
				i+1, maxRetries, url, retryInterval)
			time.Sleep(retryInterval)
		}
	}

	t.Errorf("Failed to access web app at %s after %d attempts", url, maxRetries)
}

// TestWebAppModulePlan tests that terraform plan succeeds
func TestWebAppModulePlan(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/basic",
		NoColor:      true,
		Vars: map[string]interface{}{
			"environment": "plan-test",
		},
	}

	// Run terraform init and plan
	terraform.Init(t, terraformOptions)
	planOutput := terraform.Plan(t, terraformOptions)

	// Validate that the plan contains expected resources
	assert.Contains(t, planOutput, "azurerm_resource_group.example", 
		"Plan should include resource group creation")
	assert.Contains(t, planOutput, "azurerm_service_plan.this", 
		"Plan should include service plan creation")
	assert.Contains(t, planOutput, "azurerm_linux_web_app.this", 
		"Plan should include web app creation")
}
