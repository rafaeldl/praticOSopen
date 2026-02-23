#!/usr/bin/env python3
"""
Create Google Ads App-iOS Campaign

Replicates the successful App-Android campaign for iOS.
Creates: Budget -> Campaign (PAUSED) -> Targeting -> Ad Group -> App Ad

Created on 23/02/2026. Results:
  - Campaign ID: 23598117814
  - Budget ID: 15389228376
  - Ad Group ID: 192294584543
  - Ad ID: 798163564252
"""

import warnings
warnings.filterwarnings('ignore')

import sys
from google.ads.googleads.client import GoogleAdsClient

# === Config ===
CUSTOMER_ID = '6735014760'
CONFIG_PATH = '/Users/rafaeldl/.google-ads.yaml'
APP_ID = '1534604555'  # App Store numeric ID

client = GoogleAdsClient.load_from_storage(CONFIG_PATH)
ga_service = client.get_service('GoogleAdsService')


def create_budget():
    """Step 1: Create campaign budget - R$10/day"""
    print("\n=== Step 1: Creating Campaign Budget ===")

    budget_service = client.get_service('CampaignBudgetService')
    budget_operation = client.get_type('CampaignBudgetOperation')

    budget = budget_operation.create
    budget.name = 'App-iOS'
    budget.amount_micros = 10_000_000  # R$10/day
    budget.delivery_method = client.enums.BudgetDeliveryMethodEnum.STANDARD
    budget.explicitly_shared = False

    response = budget_service.mutate_campaign_budgets(
        customer_id=CUSTOMER_ID,
        operations=[budget_operation]
    )

    budget_resource = response.results[0].resource_name
    print(f"  Budget created: {budget_resource}")
    return budget_resource


def create_campaign(budget_resource):
    """Step 2: Create campaign (PAUSED) with App Campaign settings"""
    print("\n=== Step 2: Creating Campaign (PAUSED) ===")

    campaign_service = client.get_service('CampaignService')
    campaign_operation = client.get_type('CampaignOperation')

    campaign = campaign_operation.create
    campaign.name = 'App-iOS'
    campaign.status = client.enums.CampaignStatusEnum.PAUSED
    campaign.advertising_channel_type = client.enums.AdvertisingChannelTypeEnum.MULTI_CHANNEL
    campaign.advertising_channel_sub_type = client.enums.AdvertisingChannelSubTypeEnum.APP_CAMPAIGN
    campaign.campaign_budget = budget_resource

    # App campaign settings
    campaign.app_campaign_setting.app_id = APP_ID
    campaign.app_campaign_setting.app_store = client.enums.AppCampaignAppStoreEnum.APPLE_APP_STORE
    campaign.app_campaign_setting.bidding_strategy_goal_type = (
        client.enums.AppCampaignBiddingStrategyGoalTypeEnum
        .OPTIMIZE_INSTALLS_WITHOUT_TARGET_INSTALL_COST
    )

    # Bidding strategy - maximize conversions (no target CPA)
    campaign.maximize_conversions.target_cpa_micros = 0

    # Required field (API v23+) - enum, not bool
    campaign.contains_eu_political_advertising = (
        client.enums.EuPoliticalAdvertisingStatusEnum
        .DOES_NOT_CONTAIN_EU_POLITICAL_ADVERTISING
    )

    response = campaign_service.mutate_campaigns(
        customer_id=CUSTOMER_ID,
        operations=[campaign_operation]
    )

    campaign_resource = response.results[0].resource_name
    print(f"  Campaign created: {campaign_resource}")
    return campaign_resource


def create_targeting(campaign_resource):
    """Step 3: Configure geo (Brazil) and language (Portuguese) targeting"""
    print("\n=== Step 3: Configuring Targeting ===")

    criterion_service = client.get_service('CampaignCriterionService')

    # Geo targeting - Brazil
    geo_operation = client.get_type('CampaignCriterionOperation')
    geo_criterion = geo_operation.create
    geo_criterion.campaign = campaign_resource
    geo_criterion.location.geo_target_constant = client.get_service(
        'GeoTargetConstantService'
    ).geo_target_constant_path(2076)

    # Language targeting - Portuguese
    lang_operation = client.get_type('CampaignCriterionOperation')
    lang_criterion = lang_operation.create
    lang_criterion.campaign = campaign_resource
    lang_criterion.language.language_constant = client.get_service(
        'GoogleAdsService'
    ).language_constant_path(1014)

    response = criterion_service.mutate_campaign_criteria(
        customer_id=CUSTOMER_ID,
        operations=[geo_operation, lang_operation]
    )

    for result in response.results:
        print(f"  Criterion created: {result.resource_name}")

    return True


def create_ad_group(campaign_resource):
    """Step 4: Create ad group"""
    print("\n=== Step 4: Creating Ad Group ===")

    ad_group_service = client.get_service('AdGroupService')
    ad_group_operation = client.get_type('AdGroupOperation')

    ad_group = ad_group_operation.create
    ad_group.name = 'Ad group 1'
    ad_group.campaign = campaign_resource
    ad_group.status = client.enums.AdGroupStatusEnum.ENABLED

    response = ad_group_service.mutate_ad_groups(
        customer_id=CUSTOMER_ID,
        operations=[ad_group_operation]
    )

    ad_group_resource = response.results[0].resource_name
    print(f"  Ad group created: {ad_group_resource}")
    return ad_group_resource


def create_app_ad(ad_group_resource):
    """Step 5: Create App Ad with headlines and descriptions"""
    print("\n=== Step 5: Creating App Ad ===")

    ad_group_ad_service = client.get_service('AdGroupAdService')
    ad_group_ad_operation = client.get_type('AdGroupAdOperation')

    ad_group_ad = ad_group_ad_operation.create
    ad_group_ad.ad_group = ad_group_resource
    ad_group_ad.status = client.enums.AdGroupAdStatusEnum.ENABLED

    # Headlines (max 5 for app ads, 30 chars each)
    headlines = [
        'Ordem de serviço no app',
        'Controle sua assistência',
        'OS, clientes e histórico',
        'Checklist e fotos na OS',
        'App para assistência técnica',
    ]

    for headline_text in headlines:
        headline = client.get_type('AdTextAsset')
        headline.text = headline_text
        ad_group_ad.ad.app_ad.headlines.append(headline)

    # Descriptions (max 5, 90 chars each)
    descriptions = [
        'Crie OS, registre serviços e acompanhe o status. Organização na rotina.',
        'Clientes, aparelhos e histórico em um só lugar. Simples e rápido.',
        'Faça orçamento, registre fotos e finalize serviços com agilidade.',
        'Organize entradas e saídas e evite retrabalho. Baixe e teste grátis.',
        'Funciona offline e facilita o atendimento. Gestão prática no dia a dia.',
    ]

    for desc_text in descriptions:
        desc = client.get_type('AdTextAsset')
        desc.text = desc_text
        ad_group_ad.ad.app_ad.descriptions.append(desc)

    response = ad_group_ad_service.mutate_ad_group_ads(
        customer_id=CUSTOMER_ID,
        operations=[ad_group_ad_operation]
    )

    ad_resource = response.results[0].resource_name
    print(f"  App Ad created: {ad_resource}")
    return ad_resource


def verify_campaign():
    """Step 6: Verify all created resources"""
    print("\n=== Step 6: Verifying Campaign ===")

    # Query campaign details
    query = '''
        SELECT
            campaign.id,
            campaign.name,
            campaign.status,
            campaign.advertising_channel_type,
            campaign.advertising_channel_sub_type,
            campaign.app_campaign_setting.app_id,
            campaign.app_campaign_setting.app_store,
            campaign.app_campaign_setting.bidding_strategy_goal_type,
            campaign_budget.amount_micros
        FROM campaign
        WHERE campaign.name = 'App-iOS'
    '''
    response = ga_service.search(customer_id=CUSTOMER_ID, query=query)
    for row in response:
        budget = row.campaign_budget.amount_micros / 1_000_000
        print(f"\n  Campaign: {row.campaign.name}")
        print(f"  ID: {row.campaign.id}")
        print(f"  Status: {row.campaign.status.name}")
        print(f"  Channel: {row.campaign.advertising_channel_type.name}")
        print(f"  Sub-channel: {row.campaign.advertising_channel_sub_type.name}")
        print(f"  App ID: {row.campaign.app_campaign_setting.app_id}")
        print(f"  App Store: {row.campaign.app_campaign_setting.app_store.name}")
        print(f"  Bidding Goal: {row.campaign.app_campaign_setting.bidding_strategy_goal_type.name}")
        print(f"  Budget: R${budget:.2f}/day")
        campaign_id = row.campaign.id

    # Query targeting
    query2 = f'''
        SELECT
            campaign_criterion.criterion_id,
            campaign_criterion.type,
            campaign_criterion.location.geo_target_constant,
            campaign_criterion.language.language_constant
        FROM campaign_criterion
        WHERE campaign.name = 'App-iOS'
    '''
    response2 = ga_service.search(customer_id=CUSTOMER_ID, query=query2)
    print("\n  Targeting:")
    for row in response2:
        ctype = row.campaign_criterion.type_.name
        if ctype == 'LOCATION':
            print(f"    Location: {row.campaign_criterion.location.geo_target_constant}")
        elif ctype == 'LANGUAGE':
            print(f"    Language: {row.campaign_criterion.language.language_constant}")

    # Query ad group
    query3 = f'''
        SELECT
            ad_group.id,
            ad_group.name,
            ad_group.status
        FROM ad_group
        WHERE campaign.name = 'App-iOS'
    '''
    response3 = ga_service.search(customer_id=CUSTOMER_ID, query=query3)
    print("\n  Ad Groups:")
    for row in response3:
        print(f"    {row.ad_group.name} (ID: {row.ad_group.id}) - {row.ad_group.status.name}")

    # Query ads
    query4 = f'''
        SELECT
            ad_group_ad.ad.id,
            ad_group_ad.ad.type,
            ad_group_ad.status,
            ad_group_ad.ad.app_ad.headlines,
            ad_group_ad.ad.app_ad.descriptions
        FROM ad_group_ad
        WHERE campaign.name = 'App-iOS'
    '''
    response4 = ga_service.search(customer_id=CUSTOMER_ID, query=query4)
    print("\n  Ads:")
    for row in response4:
        print(f"    Ad ID: {row.ad_group_ad.ad.id} - Type: {row.ad_group_ad.ad.type_.name} - Status: {row.ad_group_ad.status.name}")
        print(f"    Headlines: {[h.text for h in row.ad_group_ad.ad.app_ad.headlines]}")
        print(f"    Descriptions: {[d.text for d in row.ad_group_ad.ad.app_ad.descriptions]}")

    return campaign_id


def enable_campaign(campaign_id):
    """Step 7: Activate the campaign"""
    print("\n=== Step 7: Activating Campaign ===")

    campaign_service = client.get_service('CampaignService')
    campaign_operation = client.get_type('CampaignOperation')

    campaign = campaign_operation.update
    campaign.resource_name = client.get_service('CampaignService').campaign_path(
        CUSTOMER_ID, campaign_id
    )
    campaign.status = client.enums.CampaignStatusEnum.ENABLED

    # Set update mask
    from google.protobuf import field_mask_pb2
    campaign_operation.update_mask = field_mask_pb2.FieldMask(paths=['status'])

    response = campaign_service.mutate_campaigns(
        customer_id=CUSTOMER_ID,
        operations=[campaign_operation]
    )

    print(f"  Campaign activated: {response.results[0].resource_name}")
    return True


def main():
    print("=" * 60)
    print("  Google Ads - Creating App-iOS Campaign")
    print("=" * 60)

    try:
        # Step 1: Budget
        budget_resource = create_budget()

        # Step 2: Campaign (PAUSED)
        campaign_resource = create_campaign(budget_resource)

        # Step 3: Targeting
        create_targeting(campaign_resource)

        # Step 4: Ad Group
        ad_group_resource = create_ad_group(campaign_resource)

        # Step 5: App Ad
        create_app_ad(ad_group_resource)

        # Step 6: Verify
        campaign_id = verify_campaign()

        # Step 7: Activate
        enable_campaign(campaign_id)

        print("\n" + "=" * 60)
        print("  App-iOS campaign created and ENABLED!")
        print("=" * 60)

    except Exception as e:
        print(f"\n  ERROR: {e}")
        print(f"\n  Type: {type(e).__name__}")
        if hasattr(e, 'failure'):
            for error in e.failure.errors:
                print(f"  Error code: {error.error_code}")
                print(f"  Message: {error.message}")
                if error.location:
                    for field_path in error.location.field_path_elements:
                        print(f"  Field: {field_path.field_name}")
        sys.exit(1)


if __name__ == '__main__':
    main()
