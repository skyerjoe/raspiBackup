package main

/*

 REST prototype for raspiBackup

 See https://www.linux-tips-and-tricks.de/en/backup for details about raspiBackup

 If there is any requirement for a full blown REST API please contact the author

 REST calls can be protected with userid and password. Just create a file /usr/local/etc/raspiBackup.auth
 and add lines in the format 'userid:password' to define access credetials.

 To invoke raspiBackup via REST use follwing command:
     curl -u userid:password -H "Content-Type: application/json" -X POST -d '{"target":"/backup","type":"tar", "keep": 3}' http://<raspiHost>:8080/v0.1/backup

(c) 2017 - framp at linux-tips-and-tricks dot de

*/

import (
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"os/exec"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
)

const (
	executable   = "/usr/local/bin/raspiBackup.sh"
	passwordFile = "/usr/local/etc/raspiBackup.auth"
)

type parameter struct {
	Target string  `json:"target" binding:"required"`
	Type   *string `json:"type,omitempty"`
	Keep   *int    `json:"keep,omitempty"`
}

// BackupHandler - handles requests for raspiBackup
func BackupHandler(c *gin.Context) {

	var parm parameter
	err := c.BindJSON(&parm)
	if err != nil {
		msg := fmt.Sprintf("%+v", err)
		c.JSON(http.StatusBadRequest, gin.H{"Invalid payload received": msg})
		return
	}

	args := ""

	if parm.Type != nil {
		args = "-t " + *parm.Type
	}

	if parm.Keep != nil {
		args += "-k " + strconv.Itoa(*parm.Keep)
	}

	args += " " + parm.Target

	command := "sudo " + executable
	args = `"` + args + `"`
	combined := command + " " + args
	cmd := exec.Command("/bin/bash", "-c", combined)

	stdoutStderr, err := cmd.CombinedOutput()
	if err != nil {
		msg := fmt.Sprintf("%+v", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": msg, "output": string(stdoutStderr[:])})
	}
}

func main() {

	gin.SetMode(gin.ReleaseMode)
	api := gin.Default()

	passwordSet := false
	var credentialMap = map[string]string{}

	// read credentials
	if _, err := os.Stat(passwordFile); err == nil {
		fmt.Printf("INFO: Reading %v\n", passwordFile)
		credentials, err := ioutil.ReadFile(passwordFile)
		if err != nil {
			fmt.Printf("%+v", err)
			os.Exit(42)
		}

		f, err := os.Open(passwordFile)
		defer f.Close()
		if err != nil {
			log.Fatal(err)
		}

		fi, err := f.Stat()
		if err != nil {
			log.Fatal(err)
		}

		if mode := fi.Mode(); mode&077 != 0 {
			fmt.Printf("ERROR: %v not protected. %v\n", passwordFile, mode)
			os.Exit(42)
		}

		lines := strings.Split(string(credentials), "\n")

		for i, line := range lines {
			splitCredentials := strings.Split(string(line), ":")
			if len(splitCredentials) == 2 {
				uid, pwd := strings.TrimSpace(splitCredentials[0]), strings.TrimSpace(splitCredentials[1])
				credentialMap[uid] = pwd
				fmt.Printf("INFO: Line %v: Found credential definition for userid '%v'\n", i, uid)
				passwordSet = true
			} else {
				if len(line) > 0 {
					fmt.Printf("WARNING: Line %v skipped. Found '%v' which is not a valid credential definition. Expected 'userid:password'\n", i, line)
				}
			}
		}

	} else {
		fmt.Printf("WARNING: REST API not protected with basic auth. %v not found\n", passwordFile)
	}

	var v1 *gin.RouterGroup

	if passwordSet {
		v1 = api.Group("v1", gin.BasicAuth(credentialMap))
	} else {
		v1 = api.Group("v1")
	}

	{
		v1.POST("/backup", BackupHandler)
	}

	api.Run(":8080")
}