#!/usr/bin/env python3
import sys, os, datetime, xml.etree.ElementTree as ET
# shortVersion = marketing string (e.g. 0.2.1); buildVersion = CFBundleVersion
# (monotonic integer). Sparkle compares sparkle:version (the build number)
# against the installed app's CFBundleVersion, so it MUST be the build number.
path, shortVersion, buildVersion, url, length, sigline = sys.argv[1:7]
# sigline looks like: sparkle:edSignature="..." length="..."
sig = sigline.split('"')[1]
NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", NS)
if os.path.exists(path):
    tree = ET.parse(path); rss = tree.getroot(); channel = rss.find("channel")
else:
    # ElementTree emits the xmlns:sparkle declaration itself (via
    # register_namespace) when it serializes a namespaced child, so do not add
    # it here too -- that would produce a duplicate xmlns:sparkle attribute.
    rss = ET.Element("rss", {"version": "2.0"})
    channel = ET.SubElement(rss, "channel")
    ET.SubElement(channel, "title").text = "AetherPlayer"
    tree = ET.ElementTree(rss)
item = ET.SubElement(channel, "item")
ET.SubElement(item, "title").text = shortVersion
ET.SubElement(item, "{%s}version" % NS).text = buildVersion
ET.SubElement(item, "{%s}shortVersionString" % NS).text = shortVersion
ET.SubElement(item, "pubDate").text = datetime.datetime.utcnow().strftime("%a, %d %b %Y %H:%M:%S +0000")
ET.SubElement(item, "enclosure", {
    "url": url, "length": length, "type": "application/octet-stream",
    "{%s}edSignature" % NS: sig,
})
tree.write(path, encoding="UTF-8", xml_declaration=True)
print("wrote", path)
