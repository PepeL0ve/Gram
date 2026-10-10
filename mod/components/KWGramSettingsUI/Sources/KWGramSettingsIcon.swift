import Foundation
import UIKit
import Display

/// The KW Gram mark — used for the "KW Gram" row in Telegram's own settings list, the hub
/// screen's hero row, and the "KW Gram Team" footer row. Embedded as a base64-encoded JPEG
/// literal rather than shipped as an asset-catalog entry: the mod adds no files to the app
/// bundle and therefore never has to touch Telegram's asset catalog, which is the one part of
/// the project that conflicts hardest when rebasing onto a new release. The source art ships
/// its dark background baked in; the matching corner-radius clip below gives it the
/// rounded-square shape at whatever size is requested.
///
/// Cached per requested size, since the settings list and hub screen ask for it on every
/// redraw and the source bytes never change.
public func kwGramSettingsIcon(size: CGFloat = 30.0) -> UIImage? {
    return kwGramIconCache.image(size: size)
}

private final class KWGramIconCache {
    private var cached: [CGFloat: UIImage] = [:]
    private let sourceImage: UIImage? = {
        guard let data = Data(base64Encoded: kwGramIconBase64) else {
            return nil
        }
        return UIImage(data: data)
    }()

    func image(size: CGFloat) -> UIImage? {
        if let existing = self.cached[size] {
            return existing
        }
        guard let sourceImage else {
            return nil
        }
        let rendered = generateImage(CGSize(width: size, height: size), rotatedContext: { imageSize, context in
            let bounds = CGRect(origin: CGPoint(), size: imageSize)
            context.clear(bounds)
            context.saveGState()
            context.addPath(UIBezierPath(roundedRect: bounds, cornerRadius: imageSize.width * (8.0 / 30.0)).cgPath)
            context.clip()
            UIGraphicsPushContext(context)
            sourceImage.draw(in: bounds)
            UIGraphicsPopContext()
            context.restoreGState()
        })
        if let rendered {
            self.cached[size] = rendered
        }
        return rendered
    }
}

private let kwGramIconCache = KWGramIconCache()

private let kwGramIconBase64: String =
    "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAUDBAQEAwUEBAQFBQUGBwwIBwcHBw8L" +
    "CwkMEQ8SEhEPERETFhwXExQaFRERGCEYGh0dHx8fExciJCIeJBweHx7/2wBDAQUF" +
    "BQcGBw4ICA4eFBEUHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4e" +
    "Hh4eHh4eHh4eHh4eHh7/wAARCAGAAYADAREAAhEBAxEB/8QAHAABAAEFAQEAAAAA" +
    "AAAAAAAAAAECAwQFBgcI/8QAPhAAAgIBAgQEBAQDBwMEAwAAAAECAxEEIQUSMUEG" +
    "UWFxBxMigSMyUpEUobEVJEJywdHhM0NiJjQ1olNzwv/EABsBAQABBQEAAAAAAAAA" +
    "AAAAAAAEAQIDBQYH/8QANhEBAAIBAwMDAwQABAYCAwAAAAECAwQRIQUSMQZBURMi" +
    "YRQycYFCscHRIzM0Q5GhFSQ1RPD/2gAMAwEAAhEDEQA/APjQCMgMgMgMgMgMgMgM" +
    "gMgMgMgMoBsA2AZAZAkKJyDZANgGwDYBsA2AbANgGwDYBsA2AbANkMKmQGQGQGQG" +
    "QADIDIDIDIDIDIEgAK4JNgUAQwIAAAAAAAAAAAAAAAASgJAAAAAAAAAAAAAAAAAI" +
    "YEAAAAAAAAAAAAAAlASBXX1AtsCAAAAAAAAAAAAAnuA3AMAAQElQKAAAAAAAAAAA" +
    "AAAABDAgAAAAAAAAAAAAAE7gSBVX1AoYEAAAAAAAAAAAAAQE7AAKoxyXCeURyI5R" +
    "sHK8ZAgpIFNgAAAAAAAAAAAACGBAAAAAAAAAAAAAAJwgJAqh1AoYEAAAAAAAAAAA" +
    "ABIBLLAz+FcI1/FLvk6HTWXS78q2Xu+xL0uiz6q3bhrMpmk0Go1du3DWZdxwb4Z6" +
    "mcVPiethUn1hUuZ/udbo/ReW0b6i238Oz0PoXPfnUW2/h0Wm+Hnh2qCVsNTc/OVu" +
    "P6G9x+kNBSPumZdJh9DdPrH37yuXfD3w1YsRovr9rWXX9J9PtHG8f2yX9EdMtG0R" +
    "P/lo+K/DBcrlw3XtPtC6P+qNPq/Re3OC/wDUtDrvQNq86e/9S4Xjfh/ivB7HHXaW" +
    "cI5wrEswfszkNZ0zU6OZjLTb8+zh9d0nV6G0xmpMfn2aqSwyC1yCmwFAAAAAAAAA" +
    "AAIYEAAAAAAAAAAAAAAlASBVX1AoYEAAAAAAAAAAAAAAqjswbvTPh14nhOqPCp10" +
    "0Tivw3GKXP7+p3/pjq9P+RMRE+35egel+uVr/wACYiJ9vy7qrXtSxbFY80dvXNt5" +
    "d5i101n7oZsbFKClBppkmtomOGypmi0d1eYSrE9n1KTC+MsTxI54eHhr1LdoV79p" +
    "2lb1VFOpolVfXG2qSw4TWUzFnxUy17cld4+GHU6fHnxzXJG8T7PLPHfgp6CM+I8L" +
    "i56bObKu9fqvQ86696cnTROfBzX3j4eVeovS86OJz6bmvvHw4Jo45xAJAooBUAAA" +
    "AAAAAAUgAAAAAAAAAAAAAqAAVV9QLYAAAAAAAAAAAAAAEoC9pb50Xwurk4zg1KL9" +
    "TLiy2xXi9fML8WScd4vXzD2fgmrXEuEafWLrZDMl69z17p2pjV6WmX5eu9O1P6vS" +
    "1yx7wz9JqXTPlk/oezRPxZOydk/Taicdtp8NhN9HnYlbtxaY23VxnzRw3ui3dfFu" +
    "6Nk1zS2fQrVWmTadpRcoyi4TWYvZp9yl8dbx228LM9IvXttzEvHfiJ4f/sfiXztP" +
    "DGk1Dbh/4vvE8p9RdI/Q6jupH2WeN+pekfoNT3Uj7LePw5M51zchbIAAAAAAAAAI" +
    "YAAlkC5Gi2VcrFCThHClLGyz0LopaY7ojhd2WmvdtwtFq0AAAAAAAAAAKgKq+oFs" +
    "AAAAAAAAAAAAAAABKA9R+GF7s8P2VSefl3NL0TR6T6TyzbRzWfaXo3pLLNtLak+0" +
    "uhv2l7nSWjl0GXizP0NvzNKk3vHYk47b1bTSZO/Fz7L0Z4kiu+yRFu226qcsF0q2" +
    "lXGXNBP9y6J3hk7u6rVeKuGw4twXUaSUE58rlU/KS6Gq61oq6zSWpMcx4aXrmgrr" +
    "dHam3Mcx/Lwy6LjNxlFqSbTR43as0ntn2eJzWaztPsoLVAAAAAAAAAVAbCuupzko" +
    "xTcm8JLqytazado8q1rNp2jy73wh8O9XrVDV8W5tLp2sqr/uSX+h2HSfSeXUbZNR" +
    "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" +
    "YpfVNr6pvzbPTNB03BoadmKP793sXSuj6fp2LsxR/fuz5T5dluzYtpbJEcVUrL3C" +
    "ysTPMqZ2RgvN+Qmdll8lcfux5zlKWWY5ndDtebTvKmUlFc0tkim+yk37Y3li23ue" +
    "y2j5GG1+5By55yePCiLyym7F3bRvLgfiL4kcubhOhsXL/wB+cX1f6Tg/UfWpvP6b" +
    "DPHvP+jgPUvW/qz+nwzx7/7OBbbOMcWpAAAAAAAAAAAACUBcqeGBaAAAAAAAAAAJ" +
    "wAAYAMAgPRvhfTycI1F7WHZbhP0S/wCT0D0li2wXv8y7r0ri2w2v8zs6fUySj16s" +
    "6i8ulz+Fitc90F6otp5Yccb2iGZY985M8tlZacs2v0Rj35R5ne/8Lbbzhdy1inyy" +
    "G98eRfvskTbhxfxP1X4el0SfVuyX9Ecb6t1G0UxR/Li/VeomZpi/tw9Nc7ZqFcJT" +
    "nJ4SSy2cVWtrz21jlx9KWvPbWN5ekeDfACahreNr1jp1/wD1/sdz0b0tvtl1Xj4/" +
    "3ei+n/R05Ns2s8e0f7vSKaqqKo11QjXVBYjGKwkd3jxVx17axtEfD0zDhpgpFaxt" +
    "Ee0E59l0Mitsm/EIW7y3sFtY+Vq26MdoPfzLLX+GHJn24qx+bL67liLEzM7yiyyN" +
    "ceab+xbNorzK3JkrSN5YV10rJb9OyMF7zaWvyZZvPKlNv7Cq2JhyPjbxPHR1T4fo" +
    "LM6iSxZZF/k9F6nI9e65XHE4MM8z7uQ6/wBejHWcGCefeXnE5ObcpPLfVnBzMzzL" +
    "gZnuneVOxaogAAAAAAAAAAnCAYAAV1vcChgEgJAAAAEYAYAJASAAFdwEiYrIgeq+" +
    "Dav4fw3pY4w5pzf3Z6l0DF9PQ1/PL0roWP6ejr+eWw1MvqivQ2l2xzW5iEaPe7Pk" +
    "mxj/AHbq4I3vuv2T3L5tuk3twsxls35sxbo0W5mSp/XnyKxJWd5XHMTaN19rw4fi" +
    "3DeI+JvE11ehocq6cQdktoxx13OD12lz9V19q4o4jjf2cTqtDqera61cMcRxv7O/" +
    "8KeFeH8Drjaq43azH1XSXT2XY7HpXQcGgiJ23v8AL0TofprTdOiLTG9/mXSNqPXd" +
    "+R0EOnm9aeVtycpFu7H3zaeUNqG8uhXuj3LTFeZY12oc3hbR8jFbJPsh5NRNuI8L" +
    "Sll9C3dh3mVq7URqTS3l/Qttl7WDNqa442jyw7LZTlzSeWYJvM+Wuvlm88ojItiY" +
    "23It7y5Hxd4rjp42aHh0829J2rpH0Xqcj1r1BFN8Onnn5cl1r1BFInDp55+Xn9k3" +
    "KTlJtt7tvucNMzM7z5cPMzM7z5UMSodSgYAkCAIAlgQBPYAgJAAAAFVf5gKQAAAA" +
    "AAAAAAAAAAKqouclFLLbwXVjeYhdWN52+XsWjqdGh09P6K4x/kewaSn09PSvxEPV" +
    "dLj+ngpX8LdzbsfoLzypltHevaTauc/PCMmPxuz4ON5RdLCZS1toMlvtWubEUvQx" +
    "TZF79oITxBvzZb37QUycNjoeGXXtWajNcOy7v/Yk4sFsnNuIbXR9NyZvuy8Q3Wj0" +
    "9Omq+VRXGuHVpLqydjw48MbUjZ0Gn02PBXtpG0LqljaP7ld49mWckRxCMtvqXRMs" +
    "dY3W7bY15S3kUteKqXzVxsSyyU5Zk8mCbbyhWyTfmVuUsLLeEU4+VlskR5Yt2re8" +
    "a9l5mC+XedqoWbWb8UYzbbMSFNpRZZCquVlk1CEVltvZFt8tccd152hjyZa46915" +
    "2hw/ijxXZep6ThtjhU9pWrrL29DieseoJzTOPTztHz7uN6t162WfpYZ2j5cjLL3b" +
    "OV3ly+6mWWUEMAgJAAQAwAYEAAJwAAICQAFVfUCkqBQAAAAAAAAAAAAQGfwGn5/F" +
    "9JU+krYp/uTenYvq6mlfzCVocf1NRSv5etTxk9XniNnqO20bMObzZJ+pilFmZmd2" +
    "RW+XTxXRvLM1Z2ql452xsfUWdFnqYclkTNdFVd2qu+XTFyffyXuYoi2SdqsWPHkz" +
    "37ccN/w3hlWnjGVj+ZZ59l7GzwaSK8y6jQ9LphiJtzLZ4jHdkqY2bmIivMqW8v0K" +
    "W5Y5t3eDZRbbwi3bZTaKxvKxbfn6YbLzLLX+EbLn34qx3Lcxou61fdCqOZy3fReZ" +
    "S14r5YsmauOOWvv1ErnhvEfIi3yTZrMuotk/hbUvUpDDuxuJcS0nD6HbqbceUV1l" +
    "7EPV6/Do6zbJP9Imr12HTVmbz/TgPEHH9VxSbg266E/prT/qcB1Lq2XWTt4r8OH1" +
    "/Vc2snbfavw0uxqWrQ8YAgAAAjAAABIEMABIAAAAAAKq+oFJXcBIFAAAAAAAAAAC" +
    "sB3KQOg8BU/M8QVzayqoymb707i79dWfjluugYvqayN/Z6NY8LPoei2nh6BeeN2J" +
    "ncwxPKJE8rt08LHlsZLW2jZmy5IrC9oOF3auastTrpX7v2K001ssxM+GXS9My6m3" +
    "dfisOh0unqoqVdUFCK/n7myxY4pG1XU6fS1wV7aQuuSisQ6+Zkmfhmm8V4qpTy99" +
    "2Umd1nNvKJ2xr6rL8iy1+1bfLXHH5Yllrm92YpvMoWTJN1GclqyZ+WJq9bGGY1Yl" +
    "Lz7IwZNRFeKtfqNbFZ2o1s7ZTlzTbbfci98z5ay2a1p3lKe2SvdBFuGg454m0+iU" +
    "qdIlfetm/wDDH/c57qPqCmn3ph5t/wCmk6h1yuD7MXMuJ12s1Gsvd+pslOb7vt7H" +
    "FajU5NReb5J3lx2fPkz27sk7sfO+TAxIAMCAIAkABADuBIEMAgHcCQAAAAAqr6gU" +
    "iAKyBQAAAAAAAAAAAgQ7P4b0Pm1epxtiME/5nX+lcX33yup9M4/vtkddfLEDsbTt" +
    "Drc1tqrVSlO6MK4uUm9kjHXmdoR6b2tFa+W80HCo14t1GJWfp7I2GLSRH3Xnl0ek" +
    "6bFdr5PLZrZZbJkxEQ2+0VhTKUnt0RbHKy15niEbKLbaSG23lSOI5WLNRn6YbLzM" +
    "Vsnwj5dRvxVYcnkw7yizO61fdCmHNOSXku7LLXivMyxZM1MUb2azVa2y76Y/TDy8" +
    "yJkzTfhp8+stlnaOIY2TEjR5Wdbq6dJTK6+XLFfzMOo1FMFJveeIYNRqKYKza7je" +
    "OeJNTrk6NPzUUd0nvL3OK6h1vLqo7cfEOR13V8uf7acQ0G77mi33ajczsBS+oEgG" +
    "FIQFUdwJAAQwJAjcAkAYDcCQAAAAAqr6gUgCsgUAAAAAAAAAAAIqQ9D8CVfK4B8x" +
    "7O2xv9tj0D01i7NJ3fMu59PY+zTTb5lvJV2XWQqri5Skze2jutFYbmaWy2ilYb7h" +
    "egr0kP1WvrP/AERs9Npoxxv7ui0Wippo5/czm1GPXckzbZs5mKwt5beWYvLFM7+V" +
    "Nk4QWW9+yE3iscrJvXH5Yt1sp9X9iLa02neUS+W1uVrPqVjiGL2Ymr18KvprfPPz" +
    "7IjZdRFeKoOo11afbXmWrstnZNynLLZDtabTy1N8lsk72lS36lN9lixbqoxfLX9T" +
    "8+xitlj/AAo+TUbcQscnzsqz6k9mn0MU0+pxaN4YPp/U/c0XHPDzUJanQxbSX1V9" +
    "ceqOc6n0OaxOXBHHvDTa/pE1jvxePhzEk1s00zl5iYnaXPzxOykpsBUEUJGFIQFQ" +
    "AAAjAACQAEAF1AZAkAAAAVQ6gUgAAAAAAAAAAAAAldcFYHqfAaJVcH0enhFubrTx" +
    "6vc9R6Xj+npKUiOdnpPTMU101KRHMuq4dpI6WHnZL80v9De4cXZH5dbpNLGCu/uz" +
    "OZRXqSd9k21or/K022/cs5lZHK3deq1yxxzf0LbX7fDHkzRSNo8sWUstt9WRpmZ8" +
    "oVp35lbsnGuLlOWEikzEcysveKRvZqtbrpWPkrzCH82Qsuom3EeGm1GttknavhhZ" +
    "MCFut3XQqjmbx6eZZbJWkcseTLWnlg36md7wvoh5LuQ75ZyT+GvyZ7ZJ2jwmlNF1" +
    "I2Mddmw08FJZRMxw2WKu/hmVw9CXWvsm0ps5rxf4ec658Q0Vf1Le2C7+qOU670Tf" +
    "fUYY/lzfWujbR9fFH8uLksbHGOSUsbAUJApCAqAAAAABDAkCO4DuAAfYAgJAAVV9" +
    "QKO4EgAAAAAAAAAArIFBe0Vbt1dVSWeaaX8zNgp35K1j3llw178la/l7hwfSfJpj" +
    "OUVzcqSXkj2PS4eykTL2fpul+lji0+WxcuVevYl77Rs2c3iIUZbeRHMrY5Wr7eVc" +
    "sHv39C214jiGPLlisbVYcm3uYUNa1GohRDmm8t9F5mK+SMcbyxZtRXFG8+Wm1Wps" +
    "vlzSe3Zdka7Jkm88tBnz2yzvKxnJYwbsXVa2Nbca8Smv2RGy6mK8V8oubVRXivlr" +
    "nKyybnOTk89yFE2tPLXd1rzvLIqeH9SM9YSKbR5ZtUM47kmsQmUoy6ItdESacJeO" +
    "u0tlQlJevdE2k9zZ4trMiEN+hnisTExKXGOJjaXnnjngT4dq/wCL08f7rc+3+GXk" +
    "edeoOkTpMn1cf7J/9S89690mdJl+pT9suXlsc451BQkZRSEBUAAQwJAAR2AJgAHs" +
    "BIAAAAAVV9QKO4EgAAAAAAAAAArIJAdZ8OODviPGlqLE/kaXE5eTl2R0fpvp86rV" +
    "d8/tr/m6T01079XqovP7a8/29ZbSWT1CdnrG+0LbbbyW77rObcqLbORYX5v6Ft7R" +
    "XiFuXNFOI8sSTfdlkIkTM+VjV6iGnry95PojHlyxjhH1Gprhr+WlvtnbY5zlls1d" +
    "7zad5aDJltkt3Sszmox5pySS7sx2mIjeWK1orG8tbrNa5N10vEe8vMg5dRM/bVrM" +
    "+pm321YaznJF2lDjfdkU4fXZmWmyRTnyyYRJVYSYrwyacwlldO5mpvCRj4bCjEkm" +
    "uhLrES2OOIlmU5TTTJOONp3hMxxtLPqXMsolxDaYo7oUcR0FHENBbo71mNixn9L7" +
    "Mw6vSU1WG2K/ux63Q01eGcVvd45xbQXcO4hdpL4tTrljPmuzPI9Xpb6XNOK3s8f1" +
    "emvps1sdvMMMjMAykiCgAAIwBIACAGAAAAwAEgAAFVfUCkrIFAAAAAAAAAAAKq4y" +
    "lJRim29kitazadoViszMRD2nwXwxcJ4FTRKOLrF8y33Z630LQ/o9JFZjmeZewen9" +
    "DGi0tYmOZ5ltZyy8G2ny20zvOymUuSPM/sN+2FZtFI3YkpZeX3I8zvygzbed5WdV" +
    "dHT1OcuvZeZS+Sccbyw580Yabz5aK+2dtrnN5bNXktNp3loMmS2S3dK22lu9kWbw" +
    "xTaI5c94t1cv4euiDwpvPukcz17UzFIx1lz/AFfU27eyJ8tLouI20yUbPxIevVGm" +
    "0vUb4piL8w1eHV3ptE+G+0867q1bW8xf8jpcGSuWsXr4bjHat691WRGO3TBIiGaI" +
    "ZFEsNKXQz0lnxzt5ZsESa+E6tV+iTg8pbdzPSZiWfHM1nhs6MNJp7MnV5bWm227M" +
    "075Zb9O5mrO0pmG3bLLSWzRJ2bGsb8w5P4k8Fer0C4lp4fjULFmOsof8HJeqOl/W" +
    "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" +
    "6qbz7Q6v0li7tVa/xD0WTPQph6HM8Qt3yxVjPUtvxGyzNb7dmMmYqxyjbtVrrfma" +
    "iW+0dkQc1u67T6m/ffdYlJJNvojHM7co8zt5a5tzk5PuyF+6d5a+Z7rbyyao4jEz" +
    "xXhKrXaGl8bWcukopT/NJya9jnvUeTbHSjTdbvtStXJnIOcAAACQMvhOslotZG1P" +
    "6ekl5om6HVzpssXj+0nTZ5w3i3s7qqULK42QlzRkspnoOK9clYtX3dfjvF6xaFRl" +
    "ZIlsdJZz179Y9STitvDY4cndGzIg8Y8zMz1nbls9NarIJ5+pdSZS3dG7bYck5Ksi" +
    "qXLLJlrOyXjt2zwyl0ymZ4j3TfPMOC+KXA/mULjGnh9cMRvSXVdpHDerekxtGqxx" +
    "z7vPvV/SY2jVY4/l5q0efvPkYRQAJAAAIwAwAAdgD7ASgAACurqBQV2AoAAAAAAA" +
    "BUTHdopMj0X4WVKPDdVfjeVijn2X/J6B6QxbYb3/AC730hi2xXv+XXye52DsLLOp" +
    "llxXoYsk+zBmtzEMeyfJXKXksmKZ25RrW7azLSt5eX3NfPLS778reqlivH6tjHlt" +
    "tGzDnttVjQjnYwxHsi1ruy4JLGxIiE6scOV8a28/EYVLpCtfzOL9Q5O7URX4hy3W" +
    "r754r8Q5859pwAAAASmB0vhPiCa/gbX61tv+R1HQtd/+vef4b3pWq/7Nv6dH9jq4" +
    "b5cosddil27l9J7Z3Zcd+yd2yi01lPZkuOW0rMTG8L2mt+XZzdu5lpM1nhnw5Jpb" +
    "eG0raayujRK33basxMbwyaJrHKzPjt7SlYb+0rl9NV9E6boKdc4uMovumVzYq5qT" +
    "S3iVdRgrmxzjv4l4l4w4PPgvGLdK1+DJ89MvOL6HjvWOnW0GonHPieY/h4v1fp1t" +
    "BqZxz48x/DSmpatD9gJAjIEgQBIAABGQJAAAKq+oFHcbiQAAAAAAABUFsyg9R+HM" +
    "OTwzGX67ZM9N9K020O/zL0n0tXbRb/l0OWdG6RY1D/Ea8jFk8omTmzE1s8aafrsR" +
    "8k/bKJqbbY5awiNXDF1Tzby+SI+Xyi5p3tsineSRSsKU33ZcVv6kiEyIcJ4judvG" +
    "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" +
    "MAMAMAMAMAMAMAMASBKA/9k="
