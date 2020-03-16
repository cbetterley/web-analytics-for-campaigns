# Page Insights Framework

## Motivation

Campaign websites consist of many pages with different objectives (examples: Home, Issues, About the Candidate, How to Get Involved, Donation Forms, Thanks for Donating, Shop, Constituent Surveys). Product teams need visibility into conversion rates for these pages as well as which features are / aren't used by visitors. Establishing a reporting framework that scales to all pages allows an analyst to stand up reporting for a given page very quickly (~1 hour).

## Approach

Start with a SQL script template that calculates daily sessions and "core conversion events" for a given page. Core conversion events should be based on top line website KPIs.

Customize the script by adding additional engagement events, e.g. interactions with specific content or progression through a funnel.

Schedule the script to update a reporting table on a daily basis.

Clone a Tableau dashboard for any other page and point it to this page's reporting table. (this repository does not include an example report, but building the first one should be straight-forward given the reporting table structure)

Publish the dashboard in a place where any product / engineering / mobilization stakeholder can see it.

## Concepts

**Conversion Rate:** This framework uses session conversion rate:  (number of sessions including at least one of a particular event) / (number of sessions with page views on the page)

**Core Conversion Events**: Topline website KPIs, e.g. Donations and Volunteer Sign Ups. In this framework, Core Conversion events count towards the conversion rate if they occur during or after visiting the page of interest and within the same session.  It is important to include conversion events occurring elsewhere in the session because sometimes pages cannibalize the conversion of other pages.

**Engagement Events**: Page-specific things you want to measure.  For example: button clicks, navigation actions, progress through a funnel, impressions on a BTF component, form submissions. In this framework, Engagement Events are only counted if they occur on the page of interest (based on the path).