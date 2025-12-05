# Manual Guide for WSO2 Cloud Setup with Thunder Product


## TL;DR
Export following environment variables

```bash
export GOOGLE_CLIENT_ID=<your-google-client-id>
export GOOGLE_CLIENT_SECRET=<your-google-client-secret>
export ALLOWED_USER_TYPE=Customer
export GOOGLE_REDIRECT_URI=https://localhost:8090/gate/signin

export GITHUB_CLIENT_ID="<your-github-client-id>}"
export GITHUB_CLIENT_SECRET="<your-github-client-secret>}"
export GITHUB_REDIRECT_URI="https://localhost:8090/gate/signin"
```

Run following command on your extracted thunder pack root directory
```bash
curl -L https://raw.githubusercontent.com/rajithacharith/thunder-immutable-resources/refs/heads/main/wso2-cloud-setup/test_wso2_cloud_product.sh -o test_wso2_cloud_product.sh && chmod +x test_wso2_cloud_product.sh && ./test_wso2_cloud_product.sh
```

This guide walks you through the manual steps performed by the `test_wso2_cloud_product.sh` script to set up and test the WSO2 cloud scenario in your built Thunder product.

---

## 1. Prepare Environment Variables

Before starting, export the following environment variables in your terminal:

```bash
export GOOGLE_CLIENT_ID=<your-google-client-id>
export GOOGLE_CLIENT_SECRET=<your-google-client-secret>
export ALLOWED_USER_TYPE=Customer
export GOOGLE_REDIRECT_URI=https://localhost:8090/gate/signin

export GITHUB_CLIENT_ID="<your-github-client-id>}"
export GITHUB_CLIENT_SECRET="<your-github-client-secret>}"
export GITHUB_REDIRECT_URI="https://localhost:8090/gate/signin"
```

---

## 2. Download and Extract Resources

1. **Create a temporary directory:**

    ```bash
    mkdir -p wso2-setup-temp
    cd wso2-setup-temp
    ```

2. **Download the resource zip:**

    ```bash
    curl -L https://github.com/rajithacharith/thunder-immutable-resources/releases/download/v0.0.5/wso2-cloud-setup-resources.zip -o wso2-cloud-setup-resources.zip
    ```

3. **Unzip the resources:**

    ```bash
    unzip -o wso2-cloud-setup-resources.zip
    cd ..
    ```

---

## 3. Remove Existing Resource Directories

Remove any existing immutable resources and graphs in your Thunder product repository:

```bash
rm -rf repository/conf/immutable_resources
rm -rf repository/resources/graphs
```

---

## 4. Copy New Resources

Copy the extracted resources from the temp directory to your Thunder product repository:

```bash
cp -r wso2-setup-temp/immutable_resources repository/conf/
cp -r wso2-setup-temp/graphs repository/resources/
```

---

## 5. Start Thunder Without Deployment.toml

Start Thunder with security skipped (no deployment.toml):

```bash
export THUNDER_SKIP_SECURITY=true
./start.sh &
```

Wait about 10 seconds for Thunder to start.

---

## 6. Create or Get Default Organization Unit

Use the Thunder API to create or fetch the default Organization Unit (OU):

```bash
curl -k -X POST "https://localhost:8090/organization-units" \
    -H "Content-Type: application/json" \
    -d '{"handle": "default", "name": "Default", "description": "Default organization unit"}'
```

- If the OU already exists, fetch the OU list:

    ```bash
    curl -k -X GET "https://localhost:8090/organization-units"
    ```

- Extract the OU ID from the response (look for `"id":"..."`).

---

## 7. Update OU ID in User Schema

Edit the file `repository/conf/immutable_resources/user_schemas/customer.yaml` and set the correct OU ID:

```yaml
organization_unit_id: <DEFAULT_OU_ID>
```

You can do this with `sed`:

```bash
sed -i.bak "s/organization_unit_id: .*/organization_unit_id: <DEFAULT_OU_ID>/" repository/conf/immutable_resources/user_schemas/customer.yaml
rm -f repository/conf/immutable_resources/user_schemas/customer.yaml.bak
```

---

## 8. Stop Thunder

Find the process ID (PID) of Thunder and stop it:

```bash
ps aux | grep start.sh
kill <PID>
```

Or, if you know the PID from the background process, use:

```bash
kill <PID>
```

Wait a few seconds for the process to terminate.

---

## 9. Overwrite deployment.yaml

Copy the deployment.yaml from the temp directory to your product repository:

```bash
cp wso2-setup-temp/deployment.yaml repository/conf/deployment.yaml
```

---

## 10. Kill Processes on Port 8090 (if needed)

Check for and kill any processes running on 8090:

```bash
for port in 8090; do
    PID=$(lsof -ti:$port)
    if [ -n "$PID" ]; then
        kill $PID
    fi
done
```

---

## 11. Start Thunder Normally

Start Thunder with the updated configuration:

```bash
./start.sh
```

---

## 12. Cleanup

Remove the temporary setup directory:

```bash
rm -rf wso2-setup-temp
```

---

## 13. Done

Your Thunder product is now set up for the WSO2 cloud scenario with the latest resources and configuration.

Visit https://localhost:8090/develop/


