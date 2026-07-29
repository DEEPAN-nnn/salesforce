/**
 * Apex support for CustomHighlightsPanel:
 * - Follow / Unfollow via EntitySubscription
 * - Current user profile name for action visibility
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
}
