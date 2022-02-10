###its sample dockfile, update this Dockfile as required###
######## Remove this comments #############################

FROM ta-research-docker.artifactory-ehv.ta.philips.com/codequality/eslint-inline:latest

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
