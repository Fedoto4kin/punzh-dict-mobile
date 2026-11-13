import "package:flutter_test/flutter_test.dart";
import "package:punzh_dict/krl_query.dart";

void main() {
  test("prepareKrlIlikeQuery mirrors Django prepare_krl_ilike_query", () {
    expect(prepareKrlIlikeQuery("ai?"), "ai%");
    expect(prepareKrlIlikeQuery("ai."), "ai_");
    expect(prepareKrlIlikeQuery("šoba"), "soba");
    expect(prepareKrlIlikeQuery("mul’l’in"), "mullin");
    expect(prepareKrlIlikeQuery("mul'l'in"), "mullin");
    expect(prepareKrlIlikeQuery("mulʼlʼin"), "mullin");
    expect(prepareKrlIlikeQuery("mul’l’in-mal’l’in"), "mullin mallin");
    expect(prepareKrlIlikeQuery("šiksi…"), "siksi");
    expect(prepareKrlIlikeQuery("šiksi… što"), "siksi sto");
    expect(prepareKrlIlikeQuery("hüčkähtiä"), "hyckähtiä");
    expect(prepareKrlIlikeQuery("hyčkähtiä"), "hyckähtiä");
    expect(prepareKrlIlikeQuery("Hüčkähtiä"), "Hyckähtiä");
    expect(prepareKrlIlikeQuery("hüčkäht?"), "hyckäht%");
    expect(prepareKrlIlikeQuery("-raiska"), "-raiska");
    expect(prepareKrlIlikeQuery("igävähkö(ne)"), "igävähköne");
    expect(prepareKrlIlikeQuery("igävähkö(n’e)"), "igävähköne");
    expect(prepareKrlIlikeQuery("kurpa(t)"), "kurpat");
    expect(prepareKrlIlikeQuery("mi̮ajäičä"), "miajäicä");
  });

}
