/**
 * Apex support for CustomHighlightsPanel:
 * - Follow / Unfollow via EntitySubscription
 * - Current user profile name for action visibility
 * - Chatter Post / Poll (standard Highlights Panel actions)
 *
 * Set class API version to 59.0 or higher (Developer Console → Version Settings).
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

    @AuraEnabled
    public static void createFeedPost(Id recordId, String body) {
        if (recordId == null) {
            throw new AuraHandledException('Record Id is required.');
        }
        if (String.isBlank(body)) {
            throw new AuraHandledException('Post text is required.');
        }

        try {
            ConnectApi.FeedItemInput input = new ConnectApi.FeedItemInput();
            ConnectApi.MessageBodyInput bodyInput = new ConnectApi.MessageBodyInput();
            ConnectApi.TextSegmentInput textSegment = new ConnectApi.TextSegmentInput();
            textSegment.text = body.trim();
            bodyInput.messageSegments = new List<ConnectApi.MessageSegmentInput>{
                textSegment
            };
            input.body = bodyInput;
            input.feedElementType = ConnectApi.FeedElementType.FeedItem;
            input.subjectId = recordId;

            ConnectApi.ChatterFeeds.postFeedElement(
                Network.getNetworkId(),
                input
            );
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to create post. Ensure Chatter/Feed Tracking is enabled. ' +
                    e.getMessage()
            );
        }
    }

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
            for (String choiceText : choices) {
                if (String.isNotBlank(choiceText)) {
                    cleaned.add(choiceText.trim());
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
            ConnectApi.FeedItemInput input = new ConnectApi.FeedItemInput();
            input.subjectId = recordId;
            input.feedElementType = ConnectApi.FeedElementType.FeedItem;

            ConnectApi.MessageBodyInput bodyInput = new ConnectApi.MessageBodyInput();
            ConnectApi.TextSegmentInput textSegment = new ConnectApi.TextSegmentInput();
            textSegment.text = question.trim();
            bodyInput.messageSegments = new List<ConnectApi.MessageSegmentInput>();
            bodyInput.messageSegments.add(textSegment);
            input.body = bodyInput;

            ConnectApi.PollCapabilityInput pollCapability =
                new ConnectApi.PollCapabilityInput();
            pollCapability.choices = cleaned;

            ConnectApi.FeedElementCapabilitiesInput caps =
                new ConnectApi.FeedElementCapabilitiesInput();
            caps.poll = pollCapability;
            input.capabilities = caps;

            ConnectApi.ChatterFeeds.postFeedElement(
                Network.getNetworkId(),
                input
            );
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to create poll. Ensure Chatter/Feed Tracking is enabled. ' +
                    e.getMessage()
            );
        }
    }
}
