# AWS-IAM-Roles-Anywhere-Getting-Session-credentails-with-curl
Signing process with curl instead of aws_signing_helper (binary is too large for embedded systems)

## Links

https://docs.aws.amazon.com/rolesanywhere/latest/userguide/authentication-sign-process.html

python version:
https://nerdydrunk.info/aws:roles_anywhere

## Do the same with aws_signing_helper

```console
curl https://rolesanywhere.amazonaws.com/releases/1.1.1/X86_64/Linux/aws_signing_helper --output aws_signing_helper
chmod +x aws_signing_helper
./aws_signing_helper credential-process \
--certificate client.crt \
--private-key client.key \
--role-arn #insert role arn here# \
--trust-anchor-arn #insert trust anchor arn here# \
--profile-arn #insert profile arn here#
```

## Usage

provide cert in folder (client.crt client.key, privage key without password protection)
Fill in all arn information in curl_request.json

```console
chmod +x request.sh
./request.sh 
{"credentialSet":[{"assumedRoleUser":{"arn":"arn:aws:sts::***:assumed-role/ROLEarnNAME/***","assumedRoleId":"AROAQM7CT4AZDSGTE2Y4I:6c8a648800b353455b5520636b775431"},"credentials":{"accessKeyId":"ASIAQM7FT4AZPIHL7GML","expiration":"2024-01-16T00:02:43Z","secretAccessKey":"7yMiE0md0PF4XX/TIhKHYX2ZNexALsulaYgXFbH0","sessionToken":"IQoJb3JpZ2luX2VjEO///////////wEaDGV1LWNlbnRyYWwtMSJIMEYCIQDn77UDbagArgUOO06vsbLvn+Gh14bf3yDRbq6WNKEISQIhAJYs+UtYDrQZ5gpjKY7e3vUNTJl8I+jyVQpavxkDirHjKsoDCJj//////////wEQBBoMMDI3ODYxOTY2ODk4IgyPuu8PohdTgYoS9i0qngNAGvV8fmjH4knVLQAeZ0uo8B+PvyrCi6jhzyIsDnVueiiRbP144eyzc51TBfDC1+S5FbnTvNlKyugiUExVl0FPN88nJZ7P0uJU/i5lvgY29DWcDjmkjETm8Ot2yAnBChBSWM6lLXZxR5jHvCGgvLjD08lIlbNc5wyMTXUM4NuPIHiPtwkpC6zrXb2WCX4ijQXE0nvOxwsgEnkjNEn+8fs9QaLkGrCImpXYyoDgc9nq1HwyAxNp7tK2xb1YRh8D9kvUkDWPJnru4z0pgCo/g4ij/CNu7v9M/2Q9G5nrv4Kmfz27mI0ICVTtyMmjdIGaxtzeGHmxHhkwiXY/j0EVJRLOIEs4uvPNmzF9ldlTnT7768ysbmWRqhCT9UbVGx06onkWH4mpIvu3PQvMUEc2EMrHebkG6k/QxLr364pbsOyPZD4RP07t07bp4m6WJXZMfxz/G31Hpb8yJ+sIyvdEHEgOC0Jfek5L01FooxsKBxjVsM4k7+sRoyUs1cxID7K4NQD2MKHto+Jf0lnp4MEY+5QZhr5V+47Eh3+RAg10d3gwk/OWrQY66gHaG1I+zZzpMeeuGT3k1/8+kqfSiEUrXuGGq3oEZ0Ccmjh4t57h7VJyUwY8yn/7oI9SObmyN/VqHLeI16nhUWWtf2LifJgHlxBthZEHU0/4ql2t3z3nwNp3cZ06XjU22ey1lqzhKDgeHa01+3Si7VuKEFfQnyOrPCzrnTnjYxbDL71ATBwKVATkzXO3KVDt08/GLbS9av1cDAB+QHwu9KdTXMMTQHGciSTGN/SavJjMKScv1+p7ctSZercDw9TtjFCy9RjoyZSys5SgmZa1tf5ZPBgBnveVKgjsiCRidvqEMOjy1w0C+EWyAzI="},"packedPolicySize":46,"roleArn":"arn:aws:iam::***:role/ROLEarnNAME","sourceIdentity":"CN=YOURCN"}],"subjectArn":"***"}
```

## dependency

openssl
