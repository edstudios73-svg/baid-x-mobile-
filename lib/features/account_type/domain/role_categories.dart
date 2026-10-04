/// Category lists for account setup. They mirror the website (js/common.js), so a
/// profile created in the app looks the same on the website. Professional trades
/// use the ids of public.job_categories.
class RoleCategory {
  const RoleCategory(this.id, this.name, {this.desc = '', this.group = ''});
  final String id;
  final String name;
  final String desc;
  final String group;
}

const jobCategories = <RoleCategory>[
  RoleCategory('bf56961c-a599-4b4f-9c37-eea21c0e8998', 'Mason / Block Layer', group: 'Structural & Site Works'),
  RoleCategory('6ae7bf46-1564-441b-9a41-8127f8947876', 'Steel Bender / Iron Bender', group: 'Structural & Site Works'),
  RoleCategory('4bf4c8bd-c1d1-4062-814e-011e09069a0b', 'Concrete Worker / Pourer', group: 'Structural & Site Works'),
  RoleCategory('0bd54968-7270-4776-9b23-8cdb77ad15c8', 'Carpenter (Structural / Formwork)', group: 'Structural & Site Works'),
  RoleCategory('c4ea3b2a-f40c-4676-b503-39e54de0c707', 'Scaffolder', group: 'Structural & Site Works'),
  RoleCategory('151e1eb4-0ee4-48f1-ba7f-ff679e3b0881', 'Excavator Operator', group: 'Structural & Site Works'),
  RoleCategory('5f412540-9a21-43a4-ad8f-8cbe71faa511', 'Bulldozer / Grader Operator', group: 'Structural & Site Works'),
  RoleCategory('d59ead2c-deed-46ae-87d0-c79a527be23e', 'Site Foreman / Supervisor', group: 'Structural & Site Works'),
  RoleCategory('88d2584a-9b50-48a7-a53d-76f7f3038c35', 'Borehole Driller', group: 'Structural & Site Works'),
  RoleCategory('af532cf8-1fe0-4372-a0d3-cd57ddce68e4', 'Land Surveyor Assistant', group: 'Structural & Site Works'),
  RoleCategory('bb7f934f-fffa-46c3-b031-4dd6408b11ba', 'Electrician', group: 'Electrical & Mechanical'),
  RoleCategory('d868cda9-9ecc-4554-a217-617e269655db', 'AC / HVAC Technician', group: 'Electrical & Mechanical'),
  RoleCategory('1b017073-8e79-45c2-a009-cba5269b0adc', 'Generator Technician', group: 'Electrical & Mechanical'),
  RoleCategory('0c47f4ed-0601-463a-95cb-20b7f76efb30', 'Solar Panel Installer', group: 'Electrical & Mechanical'),
  RoleCategory('6d649839-d4ec-471b-bf3c-b695dd9bffde', 'Elevator / Lift Technician', group: 'Electrical & Mechanical'),
  RoleCategory('ff2622c5-5dd9-4fe4-95b0-4d3804d630c3', 'CCTV / Security Systems Installer', group: 'Electrical & Mechanical'),
  RoleCategory('231b5ac9-4bb9-487d-b7fc-ffe6c3826180', 'Network / Structured Cabling Technician', group: 'Electrical & Mechanical'),
  RoleCategory('9998564d-97e7-4769-a9b2-642f3a93610f', 'Fire Safety Systems Installer', group: 'Electrical & Mechanical'),
  RoleCategory('29e05c5d-b433-4f4f-a7af-1fc99a5ff3f6', 'Satellite Dish / TV Aerial Installer', group: 'Electrical & Mechanical'),
  RoleCategory('ddfa3c9f-d6f9-4d43-b73a-9b43d126dcff', 'Swimming Pool Technician', group: 'Electrical & Mechanical'),
  RoleCategory('3bec9905-9cef-4391-b685-f69f0dacecd3', 'Plumber', group: 'Plumbing & Water'),
  RoleCategory('b32b2aab-8845-4fb4-9df3-91bd0fcad910', 'Borehole Pump Mechanic', group: 'Plumbing & Water'),
  RoleCategory('659772be-9163-49fd-ad7c-eab795d8fd96', 'Septic Tank / Soakaway Constructor', group: 'Plumbing & Water'),
  RoleCategory('8b941981-ab7a-4cab-9ae2-ba0008cee0bf', 'Waterproofing Specialist', group: 'Plumbing & Water'),
  RoleCategory('2c4a9623-18f8-4833-b0fa-028867b3442a', 'Gutter Installer', group: 'Plumbing & Water'),
  RoleCategory('0f7a801e-a1ac-453e-a913-926c0ebb4bcc', 'Painter', group: 'Finishing & Interior'),
  RoleCategory('bf17a29f-78d2-4b04-9cd6-c47b12f8a80b', 'Tiler', group: 'Finishing & Interior'),
  RoleCategory('91c8f3d7-ae6a-481f-b719-a4b094698ea8', 'POP / Ceiling Installer', group: 'Finishing & Interior'),
  RoleCategory('339153e7-bffa-4056-b2f1-68df8b179334', 'Screeder', group: 'Finishing & Interior'),
  RoleCategory('28f17c47-33bc-4ee4-81e0-c2b635938591', 'Terrazzo / Granite Fixer', group: 'Finishing & Interior'),
  RoleCategory('30a6c143-11f7-4da9-acd1-54c56e4f4ec3', 'Interior Decorator', group: 'Finishing & Interior'),
  RoleCategory('29e43fac-36f3-47fb-9548-501138a15322', 'Wallpaper Installer', group: 'Finishing & Interior'),
  RoleCategory('6a6d1881-6d9b-45fa-be33-e9ba14bdbdd1', 'Cabinetmaker / Kitchen Cabinet Installer', group: 'Finishing & Interior'),
  RoleCategory('a154f45b-b024-4494-aedd-11a947e07297', 'Wardrobe / Closet Installer', group: 'Finishing & Interior'),
  RoleCategory('7e21e6f2-70d9-43c2-af34-c1c34be80758', 'Wood Polisher / Varnisher', group: 'Finishing & Interior'),
  RoleCategory('649769ca-a821-4a37-a0e9-746ad83ffd35', 'Upholsterer', group: 'Finishing & Interior'),
  RoleCategory('31376931-4c8c-4d18-9c3c-fe2f4c753399', 'Curtain / Blinds Installer', group: 'Finishing & Interior'),
  RoleCategory('b7a3bc27-3c95-4bd2-9d71-6deba83b6c2f', 'Glass Tinting Technician', group: 'Finishing & Interior'),
  RoleCategory('649d1fee-ec7a-431d-809b-d0d7089598a7', 'Aluminium & Glazing Installer', group: 'Finishing & Interior'),
  RoleCategory('782ba896-56aa-4988-b89b-9b278500f530', 'Locksmith', group: 'Finishing & Interior'),
  RoleCategory('5aaf67d4-6bc7-4c8d-bf71-8414a1943aca', 'Roofer', group: 'Exterior & Compound'),
  RoleCategory('642c9737-6a8d-40a2-8edd-dab46b04f831', 'Welder / Metal Fabricator', group: 'Exterior & Compound'),
  RoleCategory('5610402e-321e-433e-8138-daf4b9bc6312', 'Fence Wall Builder', group: 'Exterior & Compound'),
  RoleCategory('f8d8403b-305a-421b-96d8-9bbb99bb6686', 'Gate Fabricator / Installer', group: 'Exterior & Compound'),
  RoleCategory('49e1bc33-b589-4085-8018-696bbfd4428b', 'Interlock / Paving Block Layer', group: 'Exterior & Compound'),
  RoleCategory('7fed628e-f9d9-4d28-a4be-913750ec5895', 'Landscaper / Gardener', group: 'Exterior & Compound'),
  RoleCategory('5612beaa-7f14-4e1a-bb54-20c0c4a3b116', 'Fumigation / Pest Control Technician', group: 'Exterior & Compound'),
  RoleCategory('53f4413b-d10d-46a8-af9b-fe42b6d497ab', 'Furniture Assembler', group: 'Support & General'),
  RoleCategory('61aa3f09-77f4-498a-bd81-a6bd838ec2c2', 'Post-Construction Cleaner', group: 'Support & General'),
  RoleCategory('dc939e89-0044-4e02-90bd-74ef10937fc5', 'General Handyman (Repairs & Maintenance)', group: 'Support & General'),
];

const industries = <RoleCategory>[
  RoleCategory('construction', 'Construction', desc: 'Building, civil and contracting works'),
  RoleCategory('real_estate_development', 'Real Estate Development', desc: 'Developers and property builders'),
  RoleCategory('property_management', 'Property Management', desc: 'Managing and maintaining properties'),
  RoleCategory('architecture_engineering', 'Architecture & Engineering', desc: 'Design, drafting and engineering consultancy'),
  RoleCategory('facilities_management', 'Facilities Management', desc: 'Maintenance, cleaning and building services'),
  RoleCategory('other', 'Other', desc: 'Another construction-related industry'),
];

const specializations = <RoleCategory>[
  RoleCategory('structural', 'Structural & Civil', desc: 'Foundations, concrete, steel and site works'),
  RoleCategory('electrical_mechanical', 'Electrical & Mechanical', desc: 'Power, HVAC, solar, security and building systems'),
  RoleCategory('plumbing_water', 'Plumbing & Water', desc: 'Plumbing, boreholes, drainage and waterproofing'),
  RoleCategory('finishing_interior', 'Finishing & Interior', desc: 'Painting, tiling, ceilings, joinery and fit-out'),
  RoleCategory('exterior_compound', 'Exterior & Compound', desc: 'Roofing, fencing, paving and landscaping'),
  RoleCategory('support_general', 'General & Support', desc: 'Mixed trades, maintenance and site support'),
];

const supplyCategories = <RoleCategory>[
  RoleCategory('Building Materials', 'Building Materials', desc: 'Blocks, sand, gravel and general materials'),
  RoleCategory('Cement & Concrete', 'Cement & Concrete', desc: 'Cement, ready-mix and concrete products'),
  RoleCategory('Steel & Metalwork', 'Steel & Metalwork', desc: 'Iron rods, roofing sheets and metal fabrication'),
  RoleCategory('Timber & Roofing', 'Timber & Roofing', desc: 'Timber, trusses, roofing sheets and accessories'),
  RoleCategory('Electrical Supplies', 'Electrical Supplies', desc: 'Cables, switches, lighting and distribution'),
  RoleCategory('Plumbing Supplies', 'Plumbing Supplies', desc: 'Pipes, fittings, tanks and sanitary ware'),
  RoleCategory('Paint & Finishes', 'Paint & Finishes', desc: 'Paints, coatings, sealants and adhesives'),
  RoleCategory('Tiles & Flooring', 'Tiles & Flooring', desc: 'Tiles, granite, laminate and flooring'),
  RoleCategory('Doors, Windows & Glass', 'Doors, Windows & Glass', desc: 'Aluminium, glass, doors and windows'),
  RoleCategory('Tools & Hardware', 'Tools & Hardware', desc: 'Hand tools, power tools and fixings'),
  RoleCategory('Equipment Rental', 'Equipment Rental', desc: 'Excavators, mixers, scaffolding and machinery'),
  RoleCategory('Safety & PPE', 'Safety & PPE', desc: 'Helmets, boots, harnesses and site safety gear'),
  RoleCategory('Solar & Power', 'Solar & Power', desc: 'Solar panels, inverters, batteries and generators'),
];

const clientNeeds = <RoleCategory>[
  RoleCategory('Mason', 'Mason'),
  RoleCategory('Electrician', 'Electrician'),
  RoleCategory('Plumber', 'Plumber'),
  RoleCategory('Carpenter', 'Carpenter'),
  RoleCategory('Painter', 'Painter'),
  RoleCategory('Tiler', 'Tiler'),
  RoleCategory('Roofer', 'Roofer'),
  RoleCategory('AC / HVAC Technician', 'AC / HVAC Technician'),
  RoleCategory('Welder', 'Welder'),
  RoleCategory('General Handyman', 'General Handyman'),
];
