import Foundation

/// Downloads Hijri dates from the free AlAdhan Islamic Calendar API:
/// GET https://api.aladhan.com/v1/gToHCalendar/{month}/{year}?calendarMethod=HJCoSA|DIYANET
/// Fetches last month, this month and next month so the widgets are covered offline.
enum HijriFetcher {
    private struct Response: Decodable { let data: [Item] }
    private struct Item: Decodable { let gregorian: Gregorian; let hijri: Hijri }
    private struct Gregorian: Decodable { let date: String }          // "DD-MM-YYYY"
    private struct Hijri: Decodable { let day: String; let year: String; let month: Month }
    private struct Month: Decodable { let number: Int }

    static func fetch(source: HijriSource, around date: Date, timeZone tz: TimeZone) async -> Result<[String: HijriDay], Error> {
        guard let method = source.apiMethod else { return .success([:]) }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz

        var result: [String: HijriDay] = [:]
        do {
            for offset in -1...1 {
                guard let d = cal.date(byAdding: .month, value: offset, to: date) else { continue }
                let c = cal.dateComponents([.year, .month], from: d)
                guard let month = c.month, let year = c.year,
                      var url = URLComponents(string: "https://api.aladhan.com/v1/gToHCalendar/\(month)/\(year)") else { continue }
                url.queryItems = [URLQueryItem(name: "calendarMethod", value: method)]
                guard let requestURL = url.url else { continue }

                var request = URLRequest(url: requestURL)
                request.timeoutInterval = 15
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }

                for item in try JSONDecoder().decode(Response.self, from: data).data {
                    let g = item.gregorian.date.split(separator: "-")
                    guard g.count == 3, let day = Int(item.hijri.day), let year = Int(item.hijri.year) else { continue }
                    result["\(g[2])-\(g[1])-\(g[0])"] = HijriDay(day: day, month: item.hijri.month.number, year: year)
                }
            }
            return .success(result)
        } catch {
            return .failure(error)
        }
    }
}
