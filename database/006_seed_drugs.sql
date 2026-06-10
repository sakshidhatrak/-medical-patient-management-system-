-- ================================================================
-- 006_seed_drugs.sql
-- Common Neurosurgery Drug Master Data
-- ================================================================

INSERT INTO drugs_master (generic_name, brand_names, composition, category, default_dose, default_frequency, default_duration) VALUES
-- Analgesics / NSAIDs
('Paracetamol',         ARRAY['Calpol','Dolo 650','Crocin'],     '500mg/650mg tablet',        'analgesic',      '650mg',   'TDS',    '5 days'),
('Ibuprofen',           ARRAY['Brufen','Combiflam'],              '400mg tablet',              'nsaid',          '400mg',   'TDS',    '5 days'),
('Diclofenac',          ARRAY['Voveran','Voltaren'],              '50mg tablet',               'nsaid',          '50mg',    'BD',     '5 days'),
('Tramadol',            ARRAY['Ultracet','Tramazac'],             '50mg capsule',              'analgesic',      '50mg',    'BD',     '3 days'),
('Pregabalin',          ARRAY['Lyrica','Pregeb M'],               '75mg/150mg capsule',        'neuropathic',    '75mg',    'BD',     '1 month'),
('Gabapentin',          ARRAY['Gabapin','Neurontin'],             '300mg capsule',             'neuropathic',    '300mg',   'TDS',    '1 month'),

-- Steroids
('Dexamethasone',       ARRAY['Decadron','Dexona'],               '4mg tablet/injection',      'steroid',        '4mg',     'BD',     '5 days'),
('Methylprednisolone',  ARRAY['Medrol','Solu-Medrol'],            '4mg/8mg/16mg tablet',       'steroid',        '8mg',     'OD',     '5 days'),
('Prednisolone',        ARRAY['Wysolone'],                        '5mg/10mg/20mg/40mg tablet', 'steroid',        '40mg',    'OD',     '7 days tapering'),

-- Anticonvulsants
('Levetiracetam',       ARRAY['Levipil','Keppra'],                '250mg/500mg/1000mg tablet', 'anticonvulsant', '500mg',   'BD',     '1 month'),
('Phenytoin',           ARRAY['Eptoin','Dilantin'],               '100mg tablet/injection',    'anticonvulsant', '100mg',   'TDS',    '1 month'),
('Carbamazepine',       ARRAY['Tegretol','Mazetol'],              '100mg/200mg tablet',        'anticonvulsant', '200mg',   'BD',     '1 month'),
('Valproate',           ARRAY['Valparin','Encorate'],             '200mg/500mg tablet',        'anticonvulsant', '500mg',   'BD',     '1 month'),

-- Muscle relaxants
('Methocarbamol',       ARRAY['Robaxin'],                         '750mg tablet',              'muscle_relaxant','750mg',   'TDS',    '5 days'),
('Baclofen',            ARRAY['Lioresal','Baclof'],               '10mg tablet',               'muscle_relaxant','10mg',    'TDS',    '1 month'),
('Tizanidine',          ARRAY['Sirdalud','Tizan'],                '2mg/4mg tablet',            'muscle_relaxant','2mg',     'BD',     '2 weeks'),
('Thiocolchicoside',    ARRAY['Myoril','Muscovit'],               '4mg/8mg capsule',           'muscle_relaxant','8mg',     'BD',     '7 days'),

-- Neuroprotection
('Methylcobalamin',     ARRAY['Mecobal','Methycobal','Nerviz'],   '500mcg/1500mcg tablet',     'neuroprotective','1500mcg', 'OD',     '1 month'),
('Alpha Lipoic Acid',   ARRAY['Nuroday','Nervmax'],               '300mg/600mg tablet',        'neuroprotective','600mg',   'OD',     '1 month'),

-- Antibiotics (post-op)
('Cefuroxime',          ARRAY['Ceftum','Zinacef'],                '500mg tablet/750mg inj',    'antibiotic',     '500mg',   'BD',     '5 days'),
('Amoxicillin + Clavulanate', ARRAY['Augmentin','Mox-CV'],       '625mg tablet',              'antibiotic',     '625mg',   'BD',     '5 days'),
('Metronidazole',       ARRAY['Flagyl','Metrogyl'],               '400mg tablet',              'antibiotic',     '400mg',   'TDS',    '5 days'),

-- PPIs / GI protection
('Pantoprazole',        ARRAY['Pan','Pantodac','Nexpro'],         '40mg tablet',               'ppi',            '40mg',    'OD',     '2 weeks'),
('Ranitidine',          ARRAY['Zantac'],                          '150mg tablet',              'ppi',            '150mg',   'BD',     '2 weeks'),
('Ondansetron',         ARRAY['Emeset','Zofran'],                 '4mg/8mg tablet',            'antiemetic',     '4mg',     'TDS',    '3 days'),

-- Osmotic agents (intracranial pressure)
('Mannitol',            ARRAY['Osmitrol'],                        '20% 100ml/250ml IV',        'osmotic',        '100ml',   'Q6H',    'as directed'),
('Glycerol + Fructose', ARRAY['Glycerol Tri-Na'],                 'IV infusion',               'osmotic',        '250ml',   'BD',     'as directed'),

-- DVT prophylaxis
('Enoxaparin',          ARRAY['Clexane','Lonopin'],               '40mg/60mg injection SC',    'anticoagulant',  '40mg',    'OD',     '7 days'),
('Heparin',             ARRAY['Heparin sodium'],                  '5000 IU SC',                'anticoagulant',  '5000IU',  'BD',     'as directed'),

-- Laxatives
('Lactulose',           ARRAY['Duphalac','Lactihep'],             '10g/15ml syrup',            'laxative',       '15ml',    'BD',     '2 weeks'),
('Bisacodyl',           ARRAY['Dulcolax','Laxoberon'],            '5mg tablet',                'laxative',       '5mg',     'OD',     '5 days');
