# Support ticket CL-4471 (CLOSED)

Reporter: clinic-integrations@alderbrook-health.example
Subject: partner can't pull the feed, sent them a link

Partner at Northmoor Labs couldn't authenticate to pull the shared feed, so I
generated them a direct link good for a week. Pasting here for the record,
close the ticket.

    http://127.0.0.1:4566/alderbrook-partner-share-ab7f3a/share/partner-feed.json?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIA6O9RSOA5XPT4II7P%2F20261119%2Feu-west-1%2Fs3%2Faws4_request&X-Amz-Date=20261119T234926Z&X-Amz-Expires=604800&X-Amz-SignedHeaders=host&X-Amz-Signature=89bee4a20c9f8a9b86eb715199bd79ebaab77ce33cee597bea5a461ae57f5de6

Works without a login, just curl it. We can regenerate when it lapses.
