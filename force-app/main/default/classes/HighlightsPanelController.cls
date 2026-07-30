/**
 * Apex support for CustomHighlightsPanel:
 * - Follow / Unfollow via EntitySubscription
 * - Current user profile name for action visibility
 * - Chatter Post / Poll (standard Highlights Panel actions)
 */
public with sharing class HighlightsPanelController {
    @AuraEnabled(cacheable=true)
    public static String getCurrentUserProfileName() {
        return [
            SELECT Name
            FROM Profile
            WHERE Id = :UserInfo.getProfileId()
            LIMIT 1
        ]
        .Name;
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isFollowing(Id recordId) {
        if (recordId == null) {
            return false;
        }
        return [
                SELECT Id
                FROM EntitySubscription
                WHERE ParentId = :recordId AND SubscriberId = :UserInfo.getUserId()
                LIMIT 1
            ]
            .size() > 0;
    }

    /**
     * Toggle follow state for the current user on the given record.
     * @return true if now following, false if unfollowed
     */
    @AuraEnabled
    public static Boolean toggleFollow(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException('Record Id is required.');
        }

        List<EntitySubscription> existing = [
            SELECT Id
            FROM EntitySubscription
            WHERE ParentId = :recordId AND SubscriberId = :UserInfo.getUserId()
            LIMIT 1
        ];

        if (!existing.isEmpty()) {
            delete existing;
            return false;
        }

        insert new EntitySubscription(
            ParentId = recordId,
            SubscriberId = UserInfo.getUserId()
        );
        return true;
    }

    /**
     * Create a Chatter text post on the record feed (standard "Post" action).
     * Requires Feed Tracking enabled on the object.
     */
    @AuraEnabled
    public static void createFeedPost(Id recordId, String body) {
        if (recordId == null) {
            throw new AuraHandledException('Record Id is required.');
        }
        if (String.isBlank(body)) {
            throw new AuraHandledException('Post text is required.');
        }

        try {
            ConnectApi.FeedItemInput feedItem = new ConnectApi.FeedItemInput();
            ConnectApi.MessageBodyInput messageBody = new ConnectApi.MessageBodyInput();
            ConnectApi.TextSegmentInput textSegment = new ConnectApi.TextSegmentInput();
            textSegment.text = body.trim();
            messageBody.messageSegments = new List<ConnectApi.MessageSegmentInput>{
                textSegment
            };
            feedItem.body = messageBody;
            feedItem.feedElementType = ConnectApi.FeedElementType.FeedItem;
            feedItem.subjectId = recordId;

            ConnectApi.ChatterFeeds.postFeedElement(
                Network.getNetworkId(),
                feedItem
            );
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to create post. Ensure Chatter/Feed Tracking is enabled. ' +
                    e.getMessage()
            );
        }
    }

    /**
     * Create a Chatter poll on the record feed (standard "Poll" action).
     * choicesJson: JSON array of strings, 2–10 choices.
     */
    @AuraEnabled
    public static void createFeedPoll(
        Id recordId,
        String question,
        String choicesJson
    ) {
        if (recordId == null) {
            throw new AuraHandledException('Record Id is required.');
        }
        if (String.isBlank(question)) {
            throw new AuraHandledException('Poll question is required.');
        }

        List<String> choices;
        try {
            choices = (List<String>) JSON.deserialize(
                choicesJson,
                List<String>.class
            );
        } catch (Exception e) {
            throw new AuraHandledException('Invalid poll choices.');
        }

        List<String> cleaned = new List<String>();
        if (choices != null) {
            for (String c : choices) {
                if (String.isNotBlank(c)) {
                    cleaned.add(c.trim());
                }
            }
        }
        if (cleaned.size() < 2) {
            throw new AuraHandledException('Add at least 2 poll choices.');
        }
        if (cleaned.size() > 10) {
            throw new AuraHandledException('Maximum 10 poll choices allowed.');
        }

        try {
            ConnectApi.FeedItemInput feedItem = new ConnectApi.FeedItemInput();
            ConnectApi.MessageBodyInput messageBody = new ConnectApi.MessageBodyInput();
            ConnectApi.TextSegmentInput textSegment = new ConnectApi.TextSegmentInput();
            textSegment.text = question.trim();
            messageBody.messageSegments = new List<ConnectApi.MessageSegmentInput>{
                textSegment
            };
            feedItem.body = messageBody;
            feedItem.feedElementType = ConnectApi.FeedElementType.FeedItem;
            feedItem.subjectId = recordId;

            ConnectApi.PollCapabilityInput pollInput = new ConnectApi.PollCapabilityInput();
            pollInput.choices = cleaned;

            // Poll attaches via capabilities (not feedItem.poll)
            ConnectApi.FeedElementCapabilitiesInput capabilities =
                new ConnectApi.FeedElementCapabilitiesInput();
            capabilities.poll = pollInput;
            feedItem.capabilities = capabilities;

            ConnectApi.ChatterFeeds.postFeedElement(
                Network.getNetworkId(),
                feedItem
            );
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to create poll. Ensure Chatter/Feed Tracking is enabled. ' +
                    e.getMessage()
            );
        }
    }
}
