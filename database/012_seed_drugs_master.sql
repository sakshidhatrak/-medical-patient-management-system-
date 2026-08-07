-- Seed drugs_master table with standard medicine list.
-- Run this once on the Render PostgreSQL instance.
-- Safe to re-run: adds unique constraint then uses ON CONFLICT DO NOTHING.

CREATE UNIQUE INDEX IF NOT EXISTS uq_drugs_generic_name ON drugs_master (generic_name);

INSERT INTO drugs_master (generic_name, brand_names, default_dose, default_frequency, category, is_active) VALUES
-- Analgesics / Antipyretics
('Paracetamol 500mg',             'Crocin,Dolo 500',               '500mg',      'TDS',       'Analgesic',               true),
('Paracetamol 650mg',             'Dolo 650,Calpol 650',           '650mg',      'TDS',       'Analgesic',               true),
('Ibuprofen 400mg',               'Brufen,Combiflam',              '400mg',      'TDS',       'NSAID',                   true),
('Diclofenac 50mg',               'Voveran,Voltaren',              '50mg',       'BD',        'NSAID',                   true),
('Diclofenac 75mg',               'Voveran SR,Dynapar',            '75mg',       'BD',        'NSAID',                   true),
('Aspirin 75mg',                  'Ecosprin 75,Disprin',           '75mg',       'OD',        'Antiplatelet',            true),
('Aspirin 150mg',                 'Ecosprin 150',                  '150mg',      'OD',        'Antiplatelet',            true),
('Tramadol 50mg',                 'Ultracet,Contramal',            '50mg',       'BD',        'Opioid analgesic',        true),
('Ketorolac 10mg',                'Ketanov,Toradol',               '10mg',       'TDS',       'NSAID',                   true),
('Etoricoxib 60mg',               'Arcoxia,Etova',                 '60mg',       'OD',        'COX-2 inhibitor',         true),
('Etoricoxib 90mg',               'Arcoxia 90,Nucoxia',            '90mg',       'OD',        'COX-2 inhibitor',         true),

-- Neuro / Antiepileptics
('Levetiracetam 500mg',           'Keppra 500,Levipil',            '500mg',      'BD',        'Antiepileptic',           true),
('Levetiracetam 1000mg',          'Keppra 1000,Levipil 1000',      '1000mg',     'BD',        'Antiepileptic',           true),
('Phenytoin 100mg',               'Eptoin 100',                    '100mg',      'TDS',       'Antiepileptic',           true),
('Sodium Valproate 200mg',        'Valparin 200,Encorate',         '200mg',      'TDS',       'Antiepileptic',           true),
('Sodium Valproate 500mg',        'Valparin 500,Encorate Chrono',  '500mg',      'BD',        'Antiepileptic',           true),
('Carbamazepine 200mg',           'Tegretol 200,Mazetol',          '200mg',      'BD',        'Antiepileptic',           true),
('Oxcarbazepine 300mg',           'Trileptal 300,Oxetol',          '300mg',      'BD',        'Antiepileptic',           true),
('Clonazepam 0.5mg',              'Rivotril 0.5,Clonotril',        '0.5mg',      'OD',        'Benzodiazepine',          true),
('Pregabalin 75mg',               'Lyrica 75,Pregeb',              '75mg',       'BD',        'Neuropathic pain',        true),
('Pregabalin 150mg',              'Lyrica 150,Pregeb 150',         '150mg',      'BD',        'Neuropathic pain',        true),
('Gabapentin 300mg',              'Gabantin 300,Neurontin',        '300mg',      'TDS',       'Neuropathic pain',        true),
('Amitriptyline 10mg',            'Tryptomer 10,Sarotena',         '10mg',       'HS',        'Antidepressant/pain',     true),
('Amitriptyline 25mg',            'Tryptomer 25',                  '25mg',       'HS',        'Antidepressant/pain',     true),
('Nimodipine 30mg',               'Nimotop 30',                    '30mg',       'Q4H',       'Calcium channel blocker', true),
('Phenobarbitone 60mg',           'Gardenal 60',                   '60mg',       'BD',        'Antiepileptic',           true),
('Clobazam 10mg',                 'Frisium 10,Cloba-10',           '10mg',       'OD HS',     'Antiepileptic',           true),
('Topiramate 25mg',               'Topamax 25,Toprol',             '25mg',       'BD',        'Antiepileptic',           true),

-- Steroids
('Dexamethasone 4mg',             'Decadron,Dexona',               '4mg',        'TDS',       'Corticosteroid',          true),
('Dexamethasone 8mg',             'Decadron 8mg',                  '8mg',        'BD',        'Corticosteroid',          true),
('Prednisolone 10mg',             'Wysolone 10',                   '10mg',       'OD',        'Corticosteroid',          true),
('Prednisolone 20mg',             'Wysolone 20',                   '20mg',       'OD',        'Corticosteroid',          true),
('Methylprednisolone 4mg',        'Medrol 4',                      '4mg',        'OD',        'Corticosteroid',          true),
('Hydrocortisone 100mg IV',       'Solucortef 100',                '100mg',      'Q8H IV',    'Corticosteroid',          true),

-- Antihypertensives
('Amlodipine 5mg',                'Amlokind 5,Stamlo',             '5mg',        'OD',        'Antihypertensive',        true),
('Amlodipine 10mg',               'Amlokind 10,Norvasc',           '10mg',       'OD',        'Antihypertensive',        true),
('Atenolol 25mg',                 'Tenormin 25',                   '25mg',       'OD',        'Beta blocker',            true),
('Atenolol 50mg',                 'Tenormin 50',                   '50mg',       'OD',        'Beta blocker',            true),
('Metoprolol 25mg',               'Metolar 25,Betaloc',            '25mg',       'BD',        'Beta blocker',            true),
('Metoprolol 50mg',               'Metolar 50',                    '50mg',       'BD',        'Beta blocker',            true),
('Losartan 50mg',                 'Losar 50,Cozaar',               '50mg',       'OD',        'ARB',                     true),
('Telmisartan 40mg',              'Telma 40,Telsartan',            '40mg',       'OD',        'ARB',                     true),
('Telmisartan 80mg',              'Telma 80',                      '80mg',       'OD',        'ARB',                     true),
('Ramipril 5mg',                  'Cardace 5,Ramipace',            '5mg',        'OD',        'ACE inhibitor',           true),
('Nifedipine 10mg',               'Adalat 10',                     '10mg',       'TDS',       'Antihypertensive',        true),
('Labetalol 100mg',               'Trandate 100',                  '100mg',      'BD',        'Alpha/Beta blocker',      true),
('Bisoprolol 5mg',                'Concor 5,Bisocor',              '5mg',        'OD',        'Beta blocker',            true),
('Carvedilol 6.25mg',             'Cardivas 6.25',                 '6.25mg',     'BD',        'Beta blocker',            true),

-- Anticoagulants / Antiplatelets
('Clopidogrel 75mg',              'Plavix 75,Clopivas',            '75mg',       'OD',        'Antiplatelet',            true),
('Warfarin 2mg',                  'Warf 2,Coumadin',               '2mg',        'OD',        'Anticoagulant',           true),
('Enoxaparin 40mg',               'Clexane 40,Lonopin',            '40mg',       'OD SC',     'Anticoagulant',           true),
('Rivaroxaban 10mg',              'Xarelto 10',                    '10mg',       'OD',        'Anticoagulant',           true),

-- PPI / GI / Antiemetics
('Pantoprazole 40mg',             'Pan 40,Pantocid',               '40mg',       'OD',        'PPI',                     true),
('Omeprazole 20mg',               'Omez 20,Prilosec',              '20mg',       'OD',        'PPI',                     true),
('Rabeprazole 20mg',              'Razo 20,Veloz',                 '20mg',       'OD',        'PPI',                     true),
('Ondansetron 4mg',               'Zofran 4,Emeset',               '4mg',        'TDS',       'Antiemetic',              true),
('Metoclopramide 10mg',           'Reglan 10,Perinorm',            '10mg',       'TDS',       'Antiemetic',              true),
('Domperidone 10mg',              'Domstal 10,Motilium',           '10mg',       'TDS',       'Antiemetic',              true),
('Lactulose 10ml',                'Duphalac,Looz',                 '10ml',       'BD',        'Laxative',                true),
('Ranitidine 150mg',              'Rantac 150,Zantac',             '150mg',      'BD',        'H2 blocker',              true),

-- Antibiotics
('Amoxicillin 500mg',             'Mox 500,Amoxil',                '500mg',      'TDS',       'Antibiotic',              true),
('Amoxicillin-Clavulanate 625mg', 'Augmentin 625,Moxclav',         '625mg',      'TDS',       'Antibiotic',              true),
('Cefuroxime 500mg',              'Zinnat 500,Ceftas',             '500mg',      'BD',        'Antibiotic',              true),
('Ceftriaxone 1g IV',             'Monocef 1g,Cefaxone',           '1g',         'OD IV',     'Antibiotic',              true),
('Cefpodoxime 200mg',             'Cepodem 200,Cefoprox',          '200mg',      'BD',        'Antibiotic',              true),
('Metronidazole 400mg',           'Flagyl 400,Metrogyl',           '400mg',      'TDS',       'Antibiotic',              true),
('Ciprofloxacin 500mg',           'Cifran 500,Ciplox',             '500mg',      'BD',        'Antibiotic',              true),
('Doxycycline 100mg',             'Doxybact 100,Vibramycin',       '100mg',      'OD',        'Antibiotic',              true),
('Azithromycin 500mg',            'Zithromax 500,Azibact',         '500mg',      'OD',        'Antibiotic',              true),
('Linezolid 600mg',               'Lizolid 600,Zyvox',             '600mg',      'BD',        'Antibiotic',              true),
('Vancomycin 1g IV',              'Vancocin 1g',                   '1g',         'BD IV',     'Antibiotic',              true),

-- Antifungals / Antivirals
('Fluconazole 150mg',             'Forcan 150,Flucomed',           '150mg',      'OD',        'Antifungal',              true),
('Acyclovir 400mg',               'Zovirax 400,Acivir',            '400mg',      'TDS',       'Antiviral',               true),

-- Diuretics
('Furosemide 40mg',               'Lasix 40,Frusenex',             '40mg',       'OD',        'Diuretic',                true),
('Mannitol 20% IV',               'Mannitol 20%',                  '100ml',      'Q6H IV',    'Osmotic diuretic',        true),
('Spironolactone 25mg',           'Aldactone 25,Spiromide',        '25mg',       'OD',        'Diuretic',                true),

-- Antidiabetics
('Metformin 500mg',               'Glycomet 500,Glucophage',       '500mg',      'BD',        'Antidiabetic',            true),
('Metformin 1000mg',              'Glycomet 1000,Obimet',          '1000mg',     'BD',        'Antidiabetic',            true),
('Glimepiride 1mg',               'Amaryl 1,Glimestar',            '1mg',        'OD',        'Antidiabetic',            true),
('Glimepiride 2mg',               'Amaryl 2',                      '2mg',        'OD',        'Antidiabetic',            true),
('Human Insulin 30/70',           'Huminsulin 30/70,Mixtard',      'As directed','BD',        'Insulin',                 true),

-- Lipid Lowering
('Atorvastatin 10mg',             'Atorva 10,Lipitor',             '10mg',       'OD HS',     'Statin',                  true),
('Atorvastatin 20mg',             'Atorva 20',                     '20mg',       'OD HS',     'Statin',                  true),
('Atorvastatin 40mg',             'Atorva 40',                     '40mg',       'OD HS',     'Statin',                  true),
('Rosuvastatin 10mg',             'Rozucor 10,Crestor',            '10mg',       'OD HS',     'Statin',                  true),

-- Psychotropics / Sedatives
('Alprazolam 0.25mg',             'Alprax 0.25,Xanax',             '0.25mg',     'BD',        'Anxiolytic',              true),
('Diazepam 5mg',                  'Valium 5,Calmpose',             '5mg',        'TDS',       'Benzodiazepine',          true),
('Lorazepam 1mg',                 'Ativan 1,Trapex',               '1mg',        'BD',        'Benzodiazepine',          true),
('Zolpidem 10mg',                 'Zoldem 10,Stilnox',             '10mg',       'HS',        'Hypnotic',                true),
('Haloperidol 5mg',               'Serenace 5,Halopidol',          '5mg',        'BD',        'Antipsychotic',           true),
('Quetiapine 25mg',               'Seroquel 25,Quetirel',          '25mg',       'BD',        'Antipsychotic',           true),
('Midazolam 5mg IV',              'Dormicum 5',                    '5mg',        'Stat IV',   'Sedative',                true),
('Propofol 200mg IV',             'Propofol Lipuro',               '200mg',      'Infusion',  'Sedative',                true),

-- Vitamins / Supplements
('Vitamin D3 60000 IU',           'Uprise-D3,Caldikind Plus',      '60000 IU',   'Weekly',    'Vitamin',                 true),
('Methylcobalamin 1500mcg',       'Mecoblast,Nurokind',            '1500mcg',    'OD',        'Vitamin',                 true),
('Calcium Carbonate 500mg',       'Shelcal 500,Calcimax',          '500mg',      'BD',        'Supplement',              true),
('Ferrous Sulfate 200mg',         'Fersolate,Fefol',               '200mg',      'OD',        'Iron supplement',         true),
('Multivitamin Tablet',           'Becosules,Supradyn',            '1 tab',      'OD',        'Supplement',              true),
('Folic Acid 5mg',                'Folvite 5,Folate',              '5mg',        'OD',        'Vitamin',                 true),
('Zinc Sulfate 50mg',             'Zincovit,Zn 50',                '50mg',       'OD',        'Supplement',              true),

-- Dementia / Neuro-cognitive
('Memantine 10mg',                'Admenta 10,Namenda',            '10mg',       'BD',        'Dementia',                true),
('Donepezil 5mg',                 'Aricept 5,Donamem',             '5mg',        'OD HS',     'Dementia',                true),
('Rivastigmine 1.5mg',            'Exelon 1.5',                    '1.5mg',      'BD',        'Dementia',                true),

-- Antidepressants
('Escitalopram 10mg',             'Nexito 10,Cipralex',            '10mg',       'OD',        'Antidepressant',          true),
('Sertraline 50mg',               'Zoloft 50,Serenata',            '50mg',       'OD',        'Antidepressant',          true),
('Duloxetine 30mg',               'Cymbalta 30,Duvanta',           '30mg',       'OD',        'Antidepressant',          true),

-- Muscle Relaxants
('Baclofen 10mg',                 'Lioresal 10,Baclof',            '10mg',       'TDS',       'Muscle relaxant',         true),
('Tizanidine 2mg',                'Sirdalud 2,Tizan',              '2mg',        'TDS',       'Muscle relaxant',         true),

-- Thyroid
('Levothyroxine 50mcg',           'Eltroxin 50,Thyronorm',         '50mcg',      'OD',        'Thyroid',                 true),
('Levothyroxine 100mcg',          'Thyronorm 100',                 '100mcg',     'OD',        'Thyroid',                 true),

-- Respiratory / Allergy
('Cetirizine 10mg',               'Cetcip 10,Zyrtec',              '10mg',       'OD HS',     'Antihistamine',           true),
('Fexofenadine 120mg',            'Allegra 120',                   '120mg',      'OD',        'Antihistamine',           true),
('Montelukast 10mg',              'Montair 10,Singulair',          '10mg',       'OD HS',     'Leukotriene antagonist',  true),
('Salbutamol 2mg',                'Asthalin 2,Ventolin',           '2mg',        'TDS',       'Bronchodilator',          true),
('Theophylline 100mg',            'Deriphyllin,Theo-Dur',          '100mg',      'BD',        'Bronchodilator',          true),
('N-Acetylcysteine 600mg',        'Mucomyst,NAC 600',              '600mg',      'BD',        'Mucolytic',               true),

-- Cardiac / Others
('Digoxin 0.25mg',                'Lanoxin 0.25',                  '0.25mg',     'OD',        'Cardiac',                 true),
('Isosorbide Dinitrate 5mg',      'Isordil 5,Sorbitrate',          '5mg',        'TDS',       'Nitrate',                 true)

ON CONFLICT (generic_name) DO NOTHING;
