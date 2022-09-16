//
//  InAppConfig.swift
//  Mindbox
//
//  Created by Максим Казаков on 08.09.2022.
//

import Foundation

struct InAppConfigResponse: Decodable {
    struct InApp: Decodable {
        let id: String
        let targeting: InAppTargeting
        let form: InAppFormVariants
    }

    struct SegmentationTargeting: Decodable {
        let segment: String?
        let segmentation: String?
    }

    struct InAppTargeting: Decodable {
        let type: InAppTargetingType?
        let payload: SegmentationTargeting?

        enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.type = try? container.decodeIfPresent(InAppTargetingType.self, forKey: CodingKeys.type)
            switch type {
            case .simple:
                self.payload = try? SegmentationTargeting(from: decoder)
            case .none:
                self.payload = nil
            }
        }
    }

    struct InAppForm: Decodable {
        enum CodingKeys: String, CodingKey {
            case type = "$type"
        }

        let payload: InAppFormPayload?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            guard let type = try? container.decode(InAppFormType.self, forKey: .type) else {
                self.payload = nil
                return
            }
            switch type {
            case .simpleImage:
                let simpleImagePayload = try SimpleImageInApp(from: decoder)
                self.payload = .simpleImage(simpleImagePayload)
            }
        }
    }

    struct SimpleImageInApp: Decodable {
        let imageUrl: String
        let redirectUrl: String
        let intentPayload: String
    }

    enum InAppTargetingType: String, Decodable {
        case simple
    }

    enum InAppFormType: String, Decodable {
        case simpleImage
    }

    enum InAppFormPayload {
        case simpleImage(SimpleImageInApp)
    }

    struct InAppFormVariants: Decodable {
        let variants: [InAppForm]
    }

    let inapps: [InApp]
}
