# ClamAV Rest

[Source](https://github.com/benzino77/clamav-rest-api#Examples)

`POST /api/v1/scan` - to scan files (see examples)

`GET /api/v1/version` - to get ClamAV version

`GET /api/v1/dbsignatures` - to get local (currently used by CRA) and remote (obtained from clamav.net) virus database signatures. It can be usefull to check whether the local database is up-to-date.

```bash

curl -s -XPOST https://{appUrl}/api/v1/scan -F FILES=@file/to/scan.exe | jq


{
  "success": true,
  "data": {
    "result": [
      {
        "name": "scan.exe",
        "is_infected": false,
        "viruses": []
      }
    ]
  }
}
```
