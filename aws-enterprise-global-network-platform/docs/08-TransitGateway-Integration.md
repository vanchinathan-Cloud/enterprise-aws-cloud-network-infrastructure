# 08 - Transit Gateway Integration

## Why both Cloud WAN and Transit Gateway
Direct Connect transit VIFs attach to a Transit Gateway through a DX gateway, so a TGW remains the on-ramp for DX in each region. Cloud WAN is the global core and the policy engine; TGWs are regional edge adapters.

```
Direct Connect Gateway
   |
Regional TGW (one per region, own ASN)
   |  TGW peering to core network + route table attachment
Cloud WAN edge (segment: onprem)
   |
Cloud WAN segments (prod, nonprod, shared, ...)
```

## Components per region
| Component | Detail |
|---|---|
| Transit Gateway | Amazon-side ASN: `64601` (APAC), `64602` (MEA), `64603` (EU) |
| TGW peering | Peers to the Cloud WAN core network edge in the same region |
| TGW route table | Holds DX gateway attachment and the Cloud WAN route table attachment |
| Policy table | Required for the Cloud WAN route table attachment |
| Cloud WAN attachment | Mapped to segment `onprem` (by tag) |

## Route flow
1. On-premises `172.16.0.0/12` arrives from DX gateway into the TGW route table.
2. The Cloud WAN route table attachment propagates it into segment `onprem`.
3. Segment policy sends `prod`, `nonprod`, `shared` traffic to `onprem` through the Inspection VPC.
4. AWS prefixes (five `/16`s) are advertised back out through the DX gateway allowed prefixes.

## Rules
- No VPCs attach directly to the regional TGWs; workloads attach to Cloud WAN only.
- TGWs are owned by the Network Account and shared only for DX, never for VPC attachment.
- Use appliance mode on inspection attachments to keep flows symmetric.
- Route summarisation at the DX gateway: advertise `/16`s, not individual VPC CIDRs.

## Migration path (if existing TGW mesh)
1. Stand up Cloud WAN alongside existing TGW peering.
2. Attach new VPCs to Cloud WAN only.
3. Move existing VPCs account by account, region by region, by changing attachment tags.
4. Retire TGW-to-TGW peering when empty. Keep the TGWs for DX.

## Limits to watch
TGW attachments per TGW, routes per route table (10,000), and DX gateway allowed prefixes (20 per association). Summarise to stay clear.
