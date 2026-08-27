import '../models/package_model.dart';

/// Curated tour packages shown on the home page.
///
/// Cover images reuse the photos that exist under assets/images/places/.
/// Packages for regions without a bundled photo point at a plausible path and
/// fall back gracefully (see the image `errorBuilder` in the screens).
const List<TourPackage> tourPackages = [
  TourPackage(
    id: 'kathmandu-heritage',
    title: 'Kathmandu Heritage Tour',
    region: 'Kathmandu',
    summary:
        'Temples, stupas and living history across the Kathmandu Valley.',
    description:
        'A relaxed cultural journey through the Kathmandu Valley, taking in its '
        'most important temples, stupas and palace squares. Perfect for a short '
        'trip focused on heritage, architecture and everyday city life.',
    durationDays: 2,
    price: 12000,
    difficulty: 'Easy',
    rating: 4.6,
    imageUrl: 'assets/images/places/Swayambhunath.jpg',
    highlights: [
      'Sunrise views from Swayambhunath',
      'Evening prayers at Boudhanath Stupa',
      'Newari architecture at Durbar Square',
    ],
    includedPlaces: [
      'Swayambhunath',
      'Pashupatinath Temple',
      'Boudhanath Stupa',
      'Kathmandu Durbar Square',
    ],
  ),

  TourPackage(
    id: 'pokhara-lakeside',
    title: 'Pokhara Lakeside Getaway',
    region: 'Pokhara',
    summary:
        'Boating, waterfalls and Annapurna views from Nepal\'s lake city.',
    description:
        'An easy-going escape to Pokhara, built around Phewa Lake and the '
        'gentle attractions nearby. A great mix of relaxation and light '
        'sightseeing with the Annapurna range as a backdrop.',
    durationDays: 3,
    price: 18000,
    difficulty: 'Easy',
    rating: 4.7,
    imageUrl: 'assets/images/places/PhewaLake.jpg',
    highlights: [
      'Boating on Phewa Lake',
      'Sunset at the World Peace Pagoda',
      'Visit to Davis Falls',
    ],
    includedPlaces: [
      'Phewa Lake',
      'World Peace Pagoda',
      'Davis Falls',
      'International Mountain Museum',
    ],
  ),

  TourPackage(
    id: 'mustang-cultural-trail',
    title: 'Mustang Cultural Trail',
    region: 'Mustang',
    summary:
        'Ancient villages and high desert landscapes along the Kali Gandaki.',
    description:
        'Travel up the dramatic Kali Gandaki valley into the high desert of '
        'Mustang, visiting the sacred site of Muktinath and timeless villages '
        'of stone houses. A journey of striking scenery and deep culture.',
    durationDays: 5,
    price: 42000,
    difficulty: 'Moderate',
    rating: 4.8,
    imageUrl: 'assets/images/places/Muktinath.jpg',
    highlights: [
      'Pilgrimage to Muktinath',
      'Old Tibetan-style village of Kagbeni',
      'Apple orchards of Marpha',
    ],
    includedPlaces: [
      'Muktinath',
      'Kagbeni',
      'Marpha',
      'Jomsom',
      'Kali Gandaki Gorge',
    ],
  ),

  TourPackage(
    id: 'annapurna-base-camp',
    title: 'Annapurna Base Camp Trek',
    region: 'Annapurna',
    summary:
        'A classic trek into the heart of the Annapurna sanctuary.',
    description:
        'One of Nepal\'s most loved treks, winding through Gurung villages, '
        'rhododendron forests and terraced hills before opening into the '
        'amphitheatre of peaks at Annapurna Base Camp.',
    durationDays: 7,
    price: 55000,
    difficulty: 'Moderate',
    rating: 4.9,
    imageUrl: 'assets/images/places/AnnapurnaBaseCamp.jpg',
    highlights: [
      'Sunrise over the Annapurna range',
      'Traditional Gurung village of Ghandruk',
      'Panorama from Poon Hill',
    ],
    includedPlaces: [
      'Annapurna Base Camp',
      'Ghandruk',
      'Poon Hill',
    ],
  ),

  TourPackage(
    id: 'everest-base-camp',
    title: 'Everest Base Camp Trek',
    region: 'Everest',
    summary:
        'The legendary trek to the foot of the world\'s highest mountain.',
    description:
        'A bucket-list adventure through the Khumbu region, following Sherpa '
        'trails past Namche Bazaar and towering peaks all the way to Everest '
        'Base Camp. Demanding, remote and unforgettable.',
    durationDays: 12,
    price: 95000,
    difficulty: 'Challenging',
    rating: 4.9,
    imageUrl: 'assets/images/places/NamcheBazaar.jpg',
    highlights: [
      'Acclimatize in bustling Namche Bazaar',
      'First views of Everest from the Everest View Hotel',
      'Reach Everest Base Camp',
    ],
    includedPlaces: [
      'Namche Bazaar',
      'Everest View Hotel',
    ],
  ),

  TourPackage(
    id: 'chitwan-jungle-safari',
    title: 'Chitwan Jungle Safari',
    region: 'Chitwan',
    summary:
        'Wildlife, jungle walks and river life in Nepal\'s lowland plains.',
    description:
        'Swap the mountains for the jungle on a safari into Chitwan National '
        'Park. Spot rhinos, deer and countless birds, and enjoy the relaxed '
        'riverside atmosphere of Sauraha.',
    durationDays: 3,
    price: 22000,
    difficulty: 'Easy',
    rating: 4.5,
    imageUrl: 'assets/images/places/ChitwanNationalPark.jpg',
    highlights: [
      'Jeep safari in Chitwan National Park',
      'Canoe ride and jungle walk',
      'Sunset over the river at Sauraha',
    ],
    includedPlaces: [
      'Chitwan National Park',
      'Sauraha',
    ],
  ),
];

/// Distinct regions across all packages, preserving their first-seen order.
/// Used to build the home page's region filter chips.
List<String> get packageRegions {
  final regions = <String>[];

  for (final package in tourPackages) {
    if (!regions.contains(package.region)) {
      regions.add(package.region);
    }
  }

  return regions;
}
