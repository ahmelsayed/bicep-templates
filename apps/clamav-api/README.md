# ClamAV Rest

[Source](https://github.com/benzino77/clamav-rest-api#Examples)

`POST /api/v1/scan` - to scan files (see examples)

`GET /api/v1/version` - to get ClamAV version

`GET /api/v1/dbsignatures` - to get local (currently used by CRA) and remote (obtained from clamav.net) virus database signatures. It can be usefull to check whether the local database is up-to-date.

```bash

curl -s -XPOST https://{appUrl}/api/v1/scan -F FILES=@src/tests/1Mfile01.rnd -F FILES=@src/tests/eicar_com.zip | jq
{
  "success": true,
  "data": {
    "result": [
      {
        "name": "1Mfile01.rnd",
        "is_infected": false,
        "viruses": []
      },
      {
        "name": "eicar_com.zip",
        "is_infected": true,
        "viruses": [
          "Win.Test.EICAR_HDB-1"
        ]
      }
    ]
  }
}
```
