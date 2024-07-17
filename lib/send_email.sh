#!/bin/bash

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <recipient_email_address> <secret_code>"
    exit 1
fi

recipient_email="$1"
secret_code="$2"
message_body="Hello, Welcome to SafeChat! Your secret code is: $secret_code. This is an automated mail from SafeChat. Please don't reply to this mail. "


mutt -s "SafeChat Registration Secret Code" "$recipient_email" <<EOF
$message_body
EOF

echo "Email sent to $recipient_email"
