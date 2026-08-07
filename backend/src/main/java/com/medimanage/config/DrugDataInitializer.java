package com.medimanage.config;

import com.medimanage.feature.drug.Drug;
import com.medimanage.feature.drug.DrugRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * Seeds the drugs_master table with a standard medicine list on first startup.
 * Runs only when the table is empty, so it is safe to restart the server.
 * Doctors can add/edit medicines from the backend; the mobile app fetches
 * the live list from GET /drugs on login and caches it locally.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class DrugDataInitializer implements ApplicationRunner {

    private final DrugRepository repo;

    @Override
    public void run(ApplicationArguments args) {
        if (repo.count() > 0) return;
        log.info("Seeding drugs_master table...");
        repo.saveAll(SEED);
        log.info("Seeded {} medicines into drugs_master.", SEED.size());
    }

    private static Drug d(String generic, String brands, String dose, String freq, String cat) {
        return Drug.builder()
                .genericName(generic).brandNames(brands)
                .defaultDose(dose).defaultFrequency(freq)
                .category(cat).isActive(true).build();
    }

    private static final List<Drug> SEED = List.of(
        // Analgesics / Antipyretics
        d("Paracetamol 500mg",          "Crocin,Dolo 500",               "500mg",     "TDS",      "Analgesic"),
        d("Paracetamol 650mg",          "Dolo 650,Calpol 650",           "650mg",     "TDS",      "Analgesic"),
        d("Ibuprofen 400mg",            "Brufen,Combiflam",              "400mg",     "TDS",      "NSAID"),
        d("Diclofenac 50mg",            "Voveran,Voltaren",              "50mg",      "BD",       "NSAID"),
        d("Diclofenac 75mg",            "Voveran SR,Dynapar",            "75mg",      "BD",       "NSAID"),
        d("Aspirin 75mg",               "Ecosprin 75,Disprin",           "75mg",      "OD",       "Antiplatelet"),
        d("Aspirin 150mg",              "Ecosprin 150",                  "150mg",     "OD",       "Antiplatelet"),
        d("Tramadol 50mg",              "Ultracet,Contramal",            "50mg",      "BD",       "Opioid analgesic"),
        d("Ketorolac 10mg",             "Ketanov,Toradol",               "10mg",      "TDS",      "NSAID"),
        d("Etoricoxib 60mg",            "Arcoxia,Etova",                 "60mg",      "OD",       "COX-2 inhibitor"),
        d("Etoricoxib 90mg",            "Arcoxia 90,Nucoxia",            "90mg",      "OD",       "COX-2 inhibitor"),
        // Neuro / Antiepileptics
        d("Levetiracetam 500mg",        "Keppra 500,Levipil",            "500mg",     "BD",       "Antiepileptic"),
        d("Levetiracetam 1000mg",       "Keppra 1000,Levipil 1000",      "1000mg",    "BD",       "Antiepileptic"),
        d("Phenytoin 100mg",            "Eptoin 100",                    "100mg",     "TDS",      "Antiepileptic"),
        d("Sodium Valproate 200mg",     "Valparin 200,Encorate",         "200mg",     "TDS",      "Antiepileptic"),
        d("Sodium Valproate 500mg",     "Valparin 500,Encorate Chrono",  "500mg",     "BD",       "Antiepileptic"),
        d("Carbamazepine 200mg",        "Tegretol 200,Mazetol",          "200mg",     "BD",       "Antiepileptic"),
        d("Oxcarbazepine 300mg",        "Trileptal 300,Oxetol",          "300mg",     "BD",       "Antiepileptic"),
        d("Clonazepam 0.5mg",           "Rivotril 0.5,Clonotril",        "0.5mg",     "OD",       "Benzodiazepine"),
        d("Pregabalin 75mg",            "Lyrica 75,Pregeb",              "75mg",      "BD",       "Neuropathic pain"),
        d("Pregabalin 150mg",           "Lyrica 150,Pregeb 150",         "150mg",     "BD",       "Neuropathic pain"),
        d("Gabapentin 300mg",           "Gabantin 300,Neurontin",        "300mg",     "TDS",      "Neuropathic pain"),
        d("Amitriptyline 10mg",         "Tryptomer 10,Sarotena",         "10mg",      "HS",       "Antidepressant/pain"),
        d("Amitriptyline 25mg",         "Tryptomer 25",                  "25mg",      "HS",       "Antidepressant/pain"),
        d("Nimodipine 30mg",            "Nimotop 30",                    "30mg",      "Q4H",      "Calcium channel blocker"),
        d("Phenobarbitone 60mg",        "Gardenal 60",                   "60mg",      "BD",       "Antiepileptic"),
        d("Clobazam 10mg",              "Frisium 10,Cloba-10",           "10mg",      "OD HS",    "Antiepileptic"),
        d("Topiramate 25mg",            "Topamax 25,Toprol",             "25mg",      "BD",       "Antiepileptic"),
        // Steroids
        d("Dexamethasone 4mg",          "Decadron,Dexona",               "4mg",       "TDS",      "Corticosteroid"),
        d("Dexamethasone 8mg",          "Decadron 8mg",                  "8mg",       "BD",       "Corticosteroid"),
        d("Prednisolone 10mg",          "Wysolone 10",                   "10mg",      "OD",       "Corticosteroid"),
        d("Prednisolone 20mg",          "Wysolone 20",                   "20mg",      "OD",       "Corticosteroid"),
        d("Methylprednisolone 4mg",     "Medrol 4",                      "4mg",       "OD",       "Corticosteroid"),
        d("Hydrocortisone 100mg IV",    "Solucortef 100",                "100mg",     "Q8H IV",   "Corticosteroid"),
        // Antihypertensives
        d("Amlodipine 5mg",             "Amlokind 5,Stamlo",             "5mg",       "OD",       "Antihypertensive"),
        d("Amlodipine 10mg",            "Amlokind 10,Norvasc",           "10mg",      "OD",       "Antihypertensive"),
        d("Atenolol 25mg",              "Tenormin 25",                   "25mg",      "OD",       "Beta blocker"),
        d("Atenolol 50mg",              "Tenormin 50",                   "50mg",      "OD",       "Beta blocker"),
        d("Metoprolol 25mg",            "Metolar 25,Betaloc",            "25mg",      "BD",       "Beta blocker"),
        d("Metoprolol 50mg",            "Metolar 50",                    "50mg",      "BD",       "Beta blocker"),
        d("Losartan 50mg",              "Losar 50,Cozaar",               "50mg",      "OD",       "ARB"),
        d("Telmisartan 40mg",           "Telma 40,Telsartan",            "40mg",      "OD",       "ARB"),
        d("Telmisartan 80mg",           "Telma 80",                      "80mg",      "OD",       "ARB"),
        d("Ramipril 5mg",               "Cardace 5,Ramipace",            "5mg",       "OD",       "ACE inhibitor"),
        d("Nifedipine 10mg",            "Adalat 10",                     "10mg",      "TDS",      "Antihypertensive"),
        d("Labetalol 100mg",            "Trandate 100",                  "100mg",     "BD",       "Alpha/Beta blocker"),
        d("Bisoprolol 5mg",             "Concor 5,Bisocor",              "5mg",       "OD",       "Beta blocker"),
        d("Carvedilol 6.25mg",          "Cardivas 6.25",                 "6.25mg",    "BD",       "Beta blocker"),
        // Anticoagulants / Antiplatelets
        d("Clopidogrel 75mg",           "Plavix 75,Clopivas",            "75mg",      "OD",       "Antiplatelet"),
        d("Warfarin 2mg",               "Warf 2,Coumadin",               "2mg",       "OD",       "Anticoagulant"),
        d("Enoxaparin 40mg",            "Clexane 40,Lonopin",            "40mg",      "OD SC",    "Anticoagulant"),
        d("Rivaroxaban 10mg",           "Xarelto 10",                    "10mg",      "OD",       "Anticoagulant"),
        // PPI / GI / Antiemetics
        d("Pantoprazole 40mg",          "Pan 40,Pantocid",               "40mg",      "OD",       "PPI"),
        d("Omeprazole 20mg",            "Omez 20,Prilosec",              "20mg",      "OD",       "PPI"),
        d("Rabeprazole 20mg",           "Razo 20,Veloz",                 "20mg",      "OD",       "PPI"),
        d("Ondansetron 4mg",            "Zofran 4,Emeset",               "4mg",       "TDS",      "Antiemetic"),
        d("Metoclopramide 10mg",        "Reglan 10,Perinorm",            "10mg",      "TDS",      "Antiemetic"),
        d("Domperidone 10mg",           "Domstal 10,Motilium",           "10mg",      "TDS",      "Antiemetic"),
        d("Lactulose 10ml",             "Duphalac,Looz",                 "10ml",      "BD",       "Laxative"),
        d("Ranitidine 150mg",           "Rantac 150,Zantac",             "150mg",     "BD",       "H2 blocker"),
        // Antibiotics
        d("Amoxicillin 500mg",          "Mox 500,Amoxil",                "500mg",     "TDS",      "Antibiotic"),
        d("Amoxicillin-Clavulanate 625mg","Augmentin 625,Moxclav",       "625mg",     "TDS",      "Antibiotic"),
        d("Cefuroxime 500mg",           "Zinnat 500,Ceftas",             "500mg",     "BD",       "Antibiotic"),
        d("Ceftriaxone 1g IV",          "Monocef 1g,Cefaxone",           "1g",        "OD IV",    "Antibiotic"),
        d("Cefpodoxime 200mg",          "Cepodem 200,Cefoprox",          "200mg",     "BD",       "Antibiotic"),
        d("Metronidazole 400mg",        "Flagyl 400,Metrogyl",           "400mg",     "TDS",      "Antibiotic"),
        d("Ciprofloxacin 500mg",        "Cifran 500,Ciplox",             "500mg",     "BD",       "Antibiotic"),
        d("Doxycycline 100mg",          "Doxybact 100,Vibramycin",       "100mg",     "OD",       "Antibiotic"),
        d("Azithromycin 500mg",         "Zithromax 500,Azibact",         "500mg",     "OD",       "Antibiotic"),
        d("Linezolid 600mg",            "Lizolid 600,Zyvox",             "600mg",     "BD",       "Antibiotic"),
        d("Vancomycin 1g IV",           "Vancocin 1g",                   "1g",        "BD IV",    "Antibiotic"),
        // Antifungals / Antivirals
        d("Fluconazole 150mg",          "Forcan 150,Flucomed",           "150mg",     "OD",       "Antifungal"),
        d("Acyclovir 400mg",            "Zovirax 400,Acivir",            "400mg",     "TDS",      "Antiviral"),
        // Diuretics
        d("Furosemide 40mg",            "Lasix 40,Frusenex",             "40mg",      "OD",       "Diuretic"),
        d("Mannitol 20% IV",            "Mannitol 20%",                  "100ml",     "Q6H IV",   "Osmotic diuretic"),
        d("Spironolactone 25mg",        "Aldactone 25,Spiromide",        "25mg",      "OD",       "Diuretic"),
        // Antidiabetics
        d("Metformin 500mg",            "Glycomet 500,Glucophage",       "500mg",     "BD",       "Antidiabetic"),
        d("Metformin 1000mg",           "Glycomet 1000,Obimet",          "1000mg",    "BD",       "Antidiabetic"),
        d("Glimepiride 1mg",            "Amaryl 1,Glimestar",            "1mg",       "OD",       "Antidiabetic"),
        d("Glimepiride 2mg",            "Amaryl 2",                      "2mg",       "OD",       "Antidiabetic"),
        d("Human Insulin 30/70",        "Huminsulin 30/70,Mixtard",      "As directed","BD",      "Insulin"),
        // Lipid lowering
        d("Atorvastatin 10mg",          "Atorva 10,Lipitor",             "10mg",      "OD HS",    "Statin"),
        d("Atorvastatin 20mg",          "Atorva 20",                     "20mg",      "OD HS",    "Statin"),
        d("Atorvastatin 40mg",          "Atorva 40",                     "40mg",      "OD HS",    "Statin"),
        d("Rosuvastatin 10mg",          "Rozucor 10,Crestor",            "10mg",      "OD HS",    "Statin"),
        // Psychotropics / Sedatives
        d("Alprazolam 0.25mg",          "Alprax 0.25,Xanax",             "0.25mg",    "BD",       "Anxiolytic"),
        d("Diazepam 5mg",               "Valium 5,Calmpose",             "5mg",       "TDS",      "Benzodiazepine"),
        d("Lorazepam 1mg",              "Ativan 1,Trapex",               "1mg",       "BD",       "Benzodiazepine"),
        d("Zolpidem 10mg",              "Zoldem 10,Stilnox",             "10mg",      "HS",       "Hypnotic"),
        d("Haloperidol 5mg",            "Serenace 5,Halopidol",          "5mg",       "BD",       "Antipsychotic"),
        d("Quetiapine 25mg",            "Seroquel 25,Quetirel",          "25mg",      "BD",       "Antipsychotic"),
        d("Midazolam 5mg IV",           "Dormicum 5",                    "5mg",       "Stat IV",  "Sedative"),
        d("Propofol 200mg IV",          "Propofol Lipuro",               "200mg",     "Infusion", "Sedative"),
        // Vitamins / Supplements
        d("Vitamin D3 60000 IU",        "Uprise-D3,Caldikind Plus",      "60000 IU",  "Weekly",   "Vitamin"),
        d("Methylcobalamin 1500mcg",    "Mecoblast,Nurokind",            "1500mcg",   "OD",       "Vitamin"),
        d("Calcium Carbonate 500mg",    "Shelcal 500,Calcimax",          "500mg",     "BD",       "Supplement"),
        d("Ferrous Sulfate 200mg",      "Fersolate,Fefol",               "200mg",     "OD",       "Iron supplement"),
        d("Multivitamin Tablet",        "Becosules,Supradyn",            "1 tab",     "OD",       "Supplement"),
        d("Folic Acid 5mg",             "Folvite 5,Folate",              "5mg",       "OD",       "Vitamin"),
        d("Zinc Sulfate 50mg",          "Zincovit,Zn 50",                "50mg",      "OD",       "Supplement"),
        // Dementia / Neuro-cognitive
        d("Memantine 10mg",             "Admenta 10,Namenda",            "10mg",      "BD",       "Dementia"),
        d("Donepezil 5mg",              "Aricept 5,Donamem",             "5mg",       "OD HS",    "Dementia"),
        d("Rivastigmine 1.5mg",         "Exelon 1.5",                    "1.5mg",     "BD",       "Dementia"),
        // Antidepressants
        d("Escitalopram 10mg",          "Nexito 10,Cipralex",            "10mg",      "OD",       "Antidepressant"),
        d("Sertraline 50mg",            "Zoloft 50,Serenata",            "50mg",      "OD",       "Antidepressant"),
        d("Duloxetine 30mg",            "Cymbalta 30,Duvanta",           "30mg",      "OD",       "Antidepressant"),
        // Muscle relaxants
        d("Baclofen 10mg",              "Lioresal 10,Baclof",            "10mg",      "TDS",      "Muscle relaxant"),
        d("Tizanidine 2mg",             "Sirdalud 2,Tizan",              "2mg",       "TDS",      "Muscle relaxant"),
        // Thyroid
        d("Levothyroxine 50mcg",        "Eltroxin 50,Thyronorm",         "50mcg",     "OD",       "Thyroid"),
        d("Levothyroxine 100mcg",       "Thyronorm 100",                 "100mcg",    "OD",       "Thyroid"),
        // Respiratory / Allergy
        d("Cetirizine 10mg",            "Cetcip 10,Zyrtec",              "10mg",      "OD HS",    "Antihistamine"),
        d("Fexofenadine 120mg",         "Allegra 120",                   "120mg",     "OD",       "Antihistamine"),
        d("Montelukast 10mg",           "Montair 10,Singulair",          "10mg",      "OD HS",    "Leukotriene antagonist"),
        d("Salbutamol 2mg",             "Asthalin 2,Ventolin",           "2mg",       "TDS",      "Bronchodilator"),
        d("Theophylline 100mg",         "Deriphyllin,Theo-Dur",          "100mg",     "BD",       "Bronchodilator"),
        d("N-Acetylcysteine 600mg",     "Mucomyst,NAC 600",              "600mg",     "BD",       "Mucolytic"),
        // Cardiac
        d("Digoxin 0.25mg",             "Lanoxin 0.25",                  "0.25mg",    "OD",       "Cardiac"),
        d("Isosorbide Dinitrate 5mg",   "Isordil 5,Sorbitrate",          "5mg",       "TDS",      "Nitrate")
    );
}
